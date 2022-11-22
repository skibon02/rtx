class App {
    constructor() {
        this.bg = [0.8, 0.2, 0.4];
        this.initGraphics();
    }
    async initGraphics() {
        let canvas = document.querySelector("#c");
        // this.keydownHandler = this.keydown.bind(this);
        // this.keyupHandler = this.keyup.bind(this);
        // window.addEventListener('keydown',this.keydownHandler,false);
        // window.addEventListener('keyup',this.keyupHandler,false);
       
        this.resizeObserver = new ResizeObserver(this.resizeCanvasToDisplaySize.bind(this));
        this.resizeObserver.observe(canvas);
    
        this.gl = canvas.getContext("webgl2");
        let gl = this.gl;

        if (!gl) {
            console.log('No webGL :(');
        }
        this.resizeCanvasToDisplaySize([{target: canvas}]);
            
        
        // gl.enable(gl.BLEND);
        // gl.blendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);

        //init shaders
        var vertexShader = this.createShader(gl.VERTEX_SHADER, await fetch("shaders/vert.glsl").then(r=> r.text()));
        var fragmentShader = this.createShader(gl.FRAGMENT_SHADER, await fetch("shaders/frag.glsl").then(r=> r.text()));
        this.program = this.createProgram(vertexShader, fragmentShader);
        this.vao = gl.createVertexArray();
        gl.useProgram(this.program);
        gl.bindVertexArray(this.vao);

        this.attr_pos_loc = gl.getAttribLocation(this.program, "a_position");

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
    
        //setup the viewport
        gl.viewport(0, 0, gl.canvas.width, gl.canvas.height);
    
        this.uni_resolution_loc = gl.getUniformLocation(this.program, "u_resolution");

        gl.useProgram(this.program);
        gl.uniform2f(this.uni_resolution_loc, gl.canvas.width, gl.canvas.height);


        //start rendering cycle
        window.requestAnimationFrame(this.draw.bind(this));
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
                this.gl.useProgram(this.program);
                this.gl.uniform2f(this.uni_resolution_loc, this.gl.canvas.width, this.gl.canvas.height);
            }
        }
    }
    draw(timestamp) {  
        this.lastTimestamp = timestamp;
        if(this.stopped) {
            return;
        }
        // Clear the canvas
        this.gl.clearColor(this.bg[0],this.bg[1], this.bg[2], 1);
        this.gl.clear(this.gl.COLOR_BUFFER_BIT);

        this.gl.useProgram(this.program);
        this.gl.bindVertexArray(this.vao);

        this.gl.drawArrays(this.gl.TRIANGLES, 0, 6);

        window.requestAnimationFrame(this.draw.bind(this));
    }

    cleanup() {
        this.stopped = true;
        this.resizeObserver.disconnect();

        // window.removeEventListener('keydown', this.keydownHandler);
        // window.removeEventListener('keyup', this.keyupHandler);

        // this.gl.deleteTexture(this.bgtexture);
        // this.gl.deleteBuffer(this.vertexBuffer);

        this.gl.deleteProgram(this.program);
        this.gl.deleteVertexArray(this.vao);
        //this.gl.deleteVertexArray(this.anime_vao);

    }

}

let app = new App();