for size in 3 3.5 4 4.5 5 5.5 6 6.5; do
  for anim in base crouch defend die falling hit_with_object hurt idle jump ladder_climb pull punch push run run_shooting run_with_gun shoot_shotgun throw vertical_slide walk wave whacked; do
    magick spriter/alex_carter_1_${size}_percent/*${anim}_*.png +append strips/percent_${size}/${anim}_strip.png
  done
done
