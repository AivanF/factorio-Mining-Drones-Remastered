if mods["space-exploration"] then
  data.raw["bool-setting"]["af-mining-drones-no-burner-drill"].hidden = true
  data.raw["bool-setting"]["af-mining-drones-no-electric-drill"].hidden = true
else
  data.raw["bool-setting"]["af-mining-drones-se-allow"].hidden = true
end

if mods["aai-industry"] then
  data.raw["bool-setting"]["af-mining-drones-engine"].hidden = true
  data.raw["bool-setting"]["af-mining-drones-elengine"].hidden = true
else
  data.raw["bool-setting"]["af-mining-drones-aai-motor"].hidden = true
  data.raw["bool-setting"]["af-mining-drones-aai-elmotor"].hidden = true
  data.raw["bool-setting"]["af-mining-drones-aai-engine"].hidden = true
  data.raw["bool-setting"]["af-mining-drones-aai-elengine"].hidden = true
end
