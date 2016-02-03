if SERVER then
	CreateConVar("map_mirror_forced", "0", {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_SERVER_CAN_EXECUTE}, "Force clients to mirror the world")
else
	local map_mirror = CreateConVar("map_mirror", "0", {FCVAR_ARCHIVE}, "Mirror the world")
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

			-- Go back to the previous RT we stored earlier
			render.SetRenderTarget(oldrt)

			-- Setup our MirroredMaterial.
			MirroredMaterial:SetTexture("$basetexture", rtMirror)

			-- Draw
			render.SetMaterial(MirroredMaterial)
			render.DrawScreenQuad()

			render.RenderHUD(0, 0, ScrW(), ScrH())

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
	hook.Add("InputMouseApply", "MapMirror_FlipMouse", function(cmd, x, y, angle)
		if map_mirror_forced:GetBool() or map_mirror:GetBool() then
			local pitchchange = y * GetConVar("m_pitch"):GetFloat()
			local yawchange = x * -GetConVar("m_yaw"):GetFloat()

			angle.p = angle.p + pitchchange * 1
			angle.y = angle.y + yawchange * -1

			cmd:SetViewAngles(angle)

			return true
		end
	end)

	hook.Add("CreateMove", "MapMirror_FlipMovement", function(cmd)
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

MsgC(Color(229, 28, 35), "This server is running Map Mirror by Excl. Set 'map_mirror 1' in console to mirror the world.\n")
