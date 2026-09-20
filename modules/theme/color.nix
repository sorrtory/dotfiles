{ lib }:

# Arithmetic on the palette's hexes, for a consumer that needs a shade no role
# names. A palette exports the roles the spec settled on and nothing between
# them, so an app whose own format asks for "one step lighter than a card"
# derives it here rather than growing a role for it.

rec {
  # The three channels of a #rrggbb hex, as numbers.
  channels = hex: map (offset: lib.fromHexString (lib.substring offset 2 hex)) [ 1 3 5 ];

  toHex = value:
    let hex = lib.toHexString (builtins.floor (value + 0.5));
    in lib.toLower (if lib.stringLength hex == 1 then "0${hex}" else hex);

  # `ratio` of `to` mixed into `from`. Ratio 0 is `from` unchanged.
  mix = from: to: ratio:
    "#" + lib.concatStrings (lib.zipListsWith
      (a: b: toHex (a + (b - a) * ratio))
      (channels from)
      (channels to));

  # A CSS rgba() of a hex and an alpha, for a format that writes translucency
  # that way rather than as two more hex digits.
  # The alpha is a string, not a number: Nix prints a float with six decimal
  # places, which is not how a stylesheet is written.
  rgba = hex: alpha:
    "rgba(${lib.concatMapStringsSep ", " toString (channels hex)}, ${alpha})";

  # The same color as hue, saturation and lightness, for a consumer whose
  # format wants the three separately — Obsidian derives a whole ramp from an
  # accent given that way. Hue is in degrees; the other two are percentages,
  # rounded, because that is the precision such a format is written in.
  hsl = hex:
    let
      rgb = map (channel: channel / 255.0) (channels hex);
      r = builtins.elemAt rgb 0;
      g = builtins.elemAt rgb 1;
      b = builtins.elemAt rgb 2;
      high = lib.foldl' lib.max 0.0 rgb;
      low = lib.foldl' lib.min 1.0 rgb;
      span = high - low;
      lightness = (high + low) / 2;
      saturation =
        if span == 0.0 then 0.0
        else span / (1.0 - (if lightness > 0.5 then 2 * lightness - 1 else 1 - 2 * lightness));
      # The sixth of the circle the largest channel owns, offset by how far
      # the other two lean.
      hue6 =
        if span == 0.0 then 0.0
        else if high == r then (let raw = (g - b) / span; in if raw < 0 then raw + 6 else raw)
        else if high == g then (b - r) / span + 2
        else (r - g) / span + 4;
      round = value: builtins.floor (value + 0.5);
    in
    {
      h = round (hue6 * 60);
      s = round (saturation * 100);
      l = round (lightness * 100);
    };
}
