class App {
    constructor() {
        this.bg = [0.8, 0.2, 0.4];

        this.samples_cnt = 0;
        this.initGraphics();
        this.curFrame = 0;
        this.passes = 1;

        this.clearAfterPass = false;
    }
    async initGraphics() {
        let canvas = document.querySelector("#c");
        this.keydownHandler = this.keydown.bind(this);
        this.keyupHandler = this.keyup.bind(this);
        window.addEventListener('keydown',this.keydownHandler,false);
        window.addEventListener('keyup',this.keyupHandler,false);
       
        this.resizeObserver = new ResizeObserver(this.resizeCanvasToDisplaySize.bind(this));
        this.resizeObserver.observe(canvas);
    
        this.gl = canvas.getContext("webgl2");
        let gl = this.gl;
        // without this we can't render to RGBA32F
        if (!gl.getExtension('EXT_color_buffer_float')) {
            return alert('need EXT_color_buffer_float');
        }
        // just guessing without this we can't downsample
        if (!gl.getExtension('OES_texture_float_linear')) {
            return alert('need OES_texture_float_linear');
        }

        if (!gl) {
            console.log('No webGL :(');
        }
        this.resizeCanvasToDisplaySize([{target: canvas}]);
            
        
        gl.enable(gl.BLEND);
        gl.blendFunc(gl.ONE, gl.ONE);

        //init shaders
        var vertexShader = this.createShader(gl.VERTEX_SHADER, await fetch("shaders/vert.glsl").then(r=> r.text()));
        var fragmentShader = this.createShader(gl.FRAGMENT_SHADER, await fetch("shaders/frag.glsl").then(r=> r.text()));
        this.sample_program = this.createProgram(vertexShader, fragmentShader);
        this.vao = gl.createVertexArray();
        gl.useProgram(this.sample_program);
        gl.bindVertexArray(this.vao);

        var presentVertexShader = this.createShader(gl.VERTEX_SHADER, await fetch("shaders/pr_vert.glsl").then(r=> r.text()));
        var presentFragmentShader = this.createShader(gl.FRAGMENT_SHADER, await fetch("shaders/pr_frag.glsl").then(r=> r.text()));
        this.present_program = this.createProgram(presentVertexShader, presentFragmentShader);
        this.present_vao = gl.createVertexArray();

        this.attr_pos_loc = gl.getAttribLocation(this.sample_program, "a_position");
        this.present_attr_pos_loc = gl.getAttribLocation(this.present_program, "a_position");

        this.positionBuffer = gl.createBuffer();
        gl.bindBuffer(gl.ARRAY_BUFFER, this.positionBuffer);
        let positions = [
            -1.0,  1.0,
            1.0,  1.0,
            -1.0, -1.0,
            -1.0, -1.0,
            1.0,  1.0,
            1.0, -1.0,
        ];
        gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(positions), gl.STATIC_DRAW);

        gl.enableVertexAttribArray(this.attr_pos_loc);
        gl.vertexAttribPointer(this.attr_pos_loc, 2, this.gl.FLOAT, true, 0, 0);

        gl.bindVertexArray(this.present_vao);
        gl.enableVertexAttribArray(this.present_attr_pos_loc);
        gl.vertexAttribPointer(this.present_attr_pos_loc, 2, this.gl.FLOAT, true, 0, 0);
        gl.bindVertexArray(this.vao);

        this.gl.activeTexture(this.gl.TEXTURE0);
        this.smp_texture = gl.createTexture();
        gl.bindTexture(gl.TEXTURE_2D, this.smp_texture);
        gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA32F, gl.canvas.width, gl.canvas.height, 0, gl.RGBA, gl.FLOAT, null);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

        this.smp_fb = gl.createFramebuffer();
        gl.bindFramebuffer(gl.FRAMEBUFFER, this.smp_fb);
        gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, this.smp_texture, 0);

        //setup the viewport
        this.gl.viewport(0, 0, canvas.width, canvas.height);
    
        this.uni_resolution_loc = this.gl.getUniformLocation(this.sample_program, "u_resolution");
        this.uni_seed_loc = this.gl.getUniformLocation(this.sample_program, "u_seed");
        this.gl.uniform2f(this.uni_resolution_loc, canvas.width, canvas.height);

        this.gl.useProgram(this.present_program);
        this.gl.uniform1i(this.gl.getUniformLocation(this.present_program, "u_texture"), 0);



        //start rendering cycle
        window.requestAnimationFrame(this.draw.bind(this));
    }
    keyup(e){
        if(e.key == " "){
            this.clearAfterPass = !this.clearAfterPass;
        }
    }
    keydown(e){
        if(e.key == " "){
            e.preventDefault();
        }
    }
    createShader( type, source) {
        var shader = this.gl.createShader(type);
        this.gl.shaderSource(shader, source);
        this.gl.compileShader(shader);
        var success = this.gl.getShaderParameter(shader, this.gl.COMPILE_STATUS);
        if (success) {
            return shader;
        }

        console.log(this.gl.getShaderInfoLog(shader));
        this.gl.deleteShader(shader);
    }

    createProgram( vertexShader, fragmentShader) {
        var program = this.gl.createProgram();
        this.gl.attachShader(program, vertexShader);
        this.gl.attachShader(program, fragmentShader);
        this.gl.linkProgram(program);
        var success = this.gl.getProgramParameter(program, this.gl.LINK_STATUS);
        if (success) {
            return program;
        }

        console.log(this.gl.getProgramInfoLog(program));
        this.gl.deleteProgram(program);
    }

    resizeCanvasToDisplaySize(entries) {
        if(this.stopped)
            return;
        for(let entry of entries) {
            let canvas = entry.target;
            // Lookup the size the browser is displaying the canvas in CSS pixels.
            const dpr = window.devicePixelRatio;
            const displayWidth  = Math.round(canvas.clientWidth * dpr);
            const displayHeight = Math.round(canvas.clientHeight * dpr);

            // Check if the canvas is not the same size.
            const needResize = canvas.width  !== displayWidth || 
                                canvas.height !== displayHeight;

            if (needResize) {
                // Make the canvas the same size

                canvas.width  = displayWidth;
                canvas.height = displayHeight;
                this.gl.viewport(0, 0, this.gl.canvas.width, this.gl.canvas.height);
                this.gl.useProgram(this.sample_program);
                this.gl.uniform2f(this.uni_resolution_loc, this.gl.canvas.width, this.gl.canvas.height);
            }
        }
    }
    draw(timestamp) {  
        this.lastTimestamp = timestamp;
        if(this.stopped) {
            return;
        }

        this.gl.bindFramebuffer(this.gl.FRAMEBUFFER, this.smp_fb);

        this.gl.useProgram(this.sample_program);
        this.gl.bindVertexArray(this.vao);
        //first pass
        for(let i = 0; i < this.passes; i++) {
            this.gl.uniform1f(this.uni_seed_loc, Math.random()*timestamp * 1.623426 % 1);

            this.gl.drawArrays(this.gl.TRIANGLES, 0, 6);
        }


        //second pass
        this.gl.bindFramebuffer(this.gl.FRAMEBUFFER, null);

        this.gl.useProgram(this.present_program);
        this.gl.bindVertexArray(this.present_vao);

        this.gl.drawArrays(this.gl.TRIANGLES, 0, 6);

        if(this.clearAfterPass) {
            // reset the framebuffer
            this.gl.bindFramebuffer(this.gl.FRAMEBUFFER, this.smp_fb);
            this.gl.clearColor(0, 0, 0, 1);
            this.gl.clear(this.gl.COLOR_BUFFER_BIT);
        }

        // setTimeout(() => {
        window.requestAnimationFrame(this.draw.bind(this));
        // }, 60);
    }

    cleanup() {
        this.stopped = true;
        this.resizeObserver.disconnect();

        window.removeEventListener('keydown', this.keydownHandler);
        window.removeEventListener('keyup', this.keyupHandler);

        // this.gl.deleteTexture(this.bgtexture);
        // this.gl.deleteBuffer(this.vertexBuffer);

        this.gl.deleteProgram(this.program);
        this.gl.deleteVertexArray(this.vao);
        //this.gl.deleteVertexArray(this.anime_vao);

    }

}

let app = new App();