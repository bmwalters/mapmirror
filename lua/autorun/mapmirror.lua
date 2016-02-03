if SERVER then
	CreateConVar("map_mirror_forced", "0", {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_SERVER_CAN_EXECUTE}, "0 = not forced, 1 = force world, 2 = force world and hud")
else
	local map_mirror = CreateClientConVar("map_mirror", "0", true, false)
	local map_mirror_forced = GetConVar("map_mirror_forced")

	cvars.AddChangeCallback("map_mirror", function()
		local new = map_mirror:GetBool()

		for _, wep in pairs(weapons.GetList()) do
			wep.ViewModelFlip = new
		end

		for _, wep in pairs(LocalPlayer():GetWeapons()) do
			wep.ViewModelFlip = new
		end
	end)

	-- Variables
	local rtMirror = render.GetMorphTex0()

	-- Set up the render target and material to do the transformation
	local MirroredMaterial = CreateMaterial("MirroredMaterial",	"UnlitGeneric",	{
		["$basetexture"] = rtMirror,
		["$basetexturetransform"] = "center .5 .5 scale -1 1 rotate 0 translate 0 0",
		["$nocull"] = "1",
	})

	-- Render our mirrored scene
	hook.Add("RenderScene", "MapMirror_RenderScene", function(pos, ang)
		if map_mirror_forced:GetBool() or map_mirror:GetBool() then
			-- Save our previous RT
			local oldrt = render.GetRenderTarget()

			-- Setup the view table
			local view = {x = 0, y = 0, w = ScrW(), h = ScrH(), origin = pos, angles = ang}

			-- Push the RT and render
			render.SetRenderTarget(rtMirror)
			render.Clear(0, 0, 0, 255, true)
			render.ClearDepth()
			render.ClearStencil()

			render.PushFilterMag(TEXFILTER.ANISOTROPIC)
			render.PushFilterMin(TEXFILTER.ANISOTROPIC)

			render.RenderView(view)

			render.PopFilterMag()
			render.PopFilterMin()

			local fliphud = map_mirror_forced:GetInt() == 2 or map_mirror:GetInt() == 2

			if fliphud then
				render.RenderHUD(0,0,ScrW(),ScrH())
			end

			-- Go back to the previous RT we stored earlier
			render.SetRenderTarget(oldrt)

			-- Setup our MirroredMaterial.
			MirroredMaterial:SetTexture("$basetexture", rtMirror)

			-- Draw
			render.SetMaterial(MirroredMaterial)
			render.DrawScreenQuad()

			if not fliphud then
				render.RenderHUD(0, 0, ScrW(), ScrH())
			end

			-- Supress RenderScene
			return true
		end
	end)

	-- Apply some transformations to the Vector.ToScreen method.
	local VECTOR = FindMetaTable("Vector")
	local VECTOR_ToScreen = VECTOR.ToScreen
	function VECTOR:ToScreen()
		if not (map_mirror_forced:GetBool() or map_mirror:GetBool()) then return VECTOR_ToScreen(self) end

		local pos = VECTOR_ToScreen(self)
		pos.x = pos.x * -1 + ScrW()

		return pos
	end

	-- Parse input from the mouse and keyboard to work with out new view.
	hook.Add("InputMouseApply", "com.casualbananas.MirrorWorld.FlipMouse", function(cmd, x, y, angle)
		if map_mirror_forced:GetBool() or map_mirror:GetBool() then
			local pitchchange = y * GetConVar("m_pitch"):GetFloat()
			local yawchange = x * -GetConVar("m_yaw"):GetFloat()

			angle.p = angle.p + pitchchange * 1
			angle.y = angle.y + yawchange * -1

			cmd:SetViewAngles(angle)

			return true
		end
	end)

	hook.Add("CreateMove", "com.casualbananas.MirrorWorld.FlipMovement", function(cmd)
		if map_mirror_forced:GetBool() or map_mirror:GetBool() then
			local forward = 0
			local right = 0
			local maxspeed = LocalPlayer():GetMaxSpeed()

			if cmd:KeyDown(IN_FORWARD) then
				forward = forward + maxspeed
			end
			if cmd:KeyDown(IN_BACK) then
				forward = forward - maxspeed
			end
			if cmd:KeyDown(IN_MOVERIGHT) then
				right = right - maxspeed
			end
			if cmd:KeyDown(IN_MOVELEFT) then
				right = right + maxspeed
			end

			cmd:SetForwardMove(forward)
			cmd:SetSideMove(right)
		end
	end)
end

MsgC(Color(229, 28, 35), "This server is running MirrorWorld by Excl.\nType 'mirror' in console to mirror the world.\n")
