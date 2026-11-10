// Full range (0-255) squeezed into limited range (16-235), as the GPU itself does at a TV mode. A screen's own modes
// go out in full range, and a screen that reads every HDMI signal as limited shows them crushed and darker.
vec4 screen(vec2 uv) {
  vec4 c = umbriel_sample(uv);
  return vec4(c.rgb * (219.0 / 255.0) + c.a * (16.0 / 255.0), c.a);
}
