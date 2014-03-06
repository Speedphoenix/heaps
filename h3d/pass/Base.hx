package h3d.pass;

@:build(hxsl.Macros.buildGlobals())
@:access(h3d.mat.Pass)
class Base {

	var ctx : h3d.scene.RenderContext;
	var manager : h3d.shader.Manager;
	var globals(get, never) : hxsl.Globals;
	inline function get_globals() return manager.globals;

	@global("camera.view") var cameraView : h3d.Matrix = ctx.camera.mcam;
	@global("camera.proj") var cameraProj : h3d.Matrix = ctx.camera.mproj;
	@global("camera.position") var cameraPos : h3d.Vector = ctx.camera.pos;
	@global("camera.projDiag") var cameraProjDiag : h3d.Vector = new h3d.Vector(ctx.camera.mproj._11,ctx.camera.mproj._22,ctx.camera.mproj._33,ctx.camera.mproj._44);
	@global("camera.viewProj") var cameraViewProj : h3d.Matrix = ctx.camera.m;
	@global("camera.inverseViewProj") var cameraInverseViewProj : h3d.Matrix = ctx.camera.getInverseViewProj();
	@global("global.time") var globalTime : Float = ctx.time;
	@global("global.modelView") var globalModelView : h3d.Matrix;
	@global("global.modelViewInverse") var globalModelViewInverse : h3d.Matrix;
	@global("global.ambientLight") var ambientLight : h3d.Vector;
	
	public function new() {
		manager = new h3d.shader.Manager(["output.position", "output.color"]);
		initGlobals();
		setAmbientLight(new h3d.Vector(1, 1, 1));
	}
	
	public function setAmbientLight( v : h3d.Vector ) {
		ambientLight.set(globals, v);
	}
	
	public function compileShader( p : h3d.mat.Pass ) {
		return manager.compileShaders(p.getShadersRec());
	}
	
	function allocBuffer( s : hxsl.RuntimeShader, shaders : Array<hxsl.Shader> ) {
		var buf = new h3d.shader.Buffers(s);
		manager.fillGlobals(buf, s);
		manager.fillParams(buf, s, shaders);
		return buf;
	}
	
	@:access(h3d.scene)
	public function draw( ctx : h3d.scene.RenderContext, passes : Object ) {
		this.ctx = ctx;
		setGlobals();
		var p = passes;
		while( p != null ) {
			// TODO : use linked list for shaders (no allocation)
			var shaders = p.pass.getShadersRec();
			if( p.pass.enableLights ) {
				if( p.pass.parentPass == null ) shaders = shaders.copy();
				var l = ctx.lights;
				while( l != null ) {
					shaders.push(l.shader);
					l = l.nextLight;
				}
			}
			var shader = manager.compileShaders(shaders);
			// TODO : sort passes by shader/textures
			globalModelView.set(globals, p.obj.absPos);
			globalModelViewInverse.set(globals, p.obj.getInvPos());
			ctx.engine.selectShader(shader);
			// TODO : reuse buffers between calls
			var buf = allocBuffer(shader, shaders);
			ctx.engine.selectMaterial(p.pass);
			ctx.engine.uploadShaderBuffers(buf, Globals);
			ctx.engine.uploadShaderBuffers(buf, Params);
			ctx.engine.uploadShaderBuffers(buf, Textures);
			ctx.drawPass = p;
			p.obj.draw(ctx);
			p = p.next;
		}
		ctx.drawPass = null;
		this.ctx = null;
	}
	
}