# Explain UI changes with annotations

Present the new screenshot with a few numbered boxes, highlights, or arrows that
explain meaningful changes. Keep the original captures available. This procedure
uses existing tools; it adds no Shaka command or automatic verification gate.

## Inspect the comparison

1. Inspect the original before and after captures and compare the whole affected
   view, including surrounding content. Check for intended changes, unexpected
   differences, and unresolved questions before choosing callouts.
2. Use the same route, viewport, theme, scroll position, test data, and interaction
   step when possible. Wait for fonts and loading to settle; prefer lossless PNG
   captures from the same renderer. Capture a taller viewport for below-fold changes.
3. Explain alignment limits when layout, animation, or live data differ. Annotations
   can explain a changed layout without claiming its captures are pixel-aligned.
   Retain desktop and mobile evidence for the views the change affects, and a short
   recording when timing or interaction matters.

## Annotate the after capture

- Keep its normal colors and text readable. Draw thin outlines or restrained
  highlights around meaningful regions, with numbered markers and short captions.
  Use color with numbers or text so the meaning does not depend on color alone.
- Give each callout a specific explanation: “1: Added expected-experience guide”
  or “2: Unexpected footer shift.” Label unresolved differences as unresolved.
  Inspecting the full view remains necessary beyond the selected callouts.
- Use arrows for movement or spacing changes. Show a labeled before crop beside
  the after capture when explaining a removal or a detail that needs comparison.
- Choose regions from the inspected comparison, rather than boxing every cluster
  of changed pixels. Keep captions and markers clear of important UI content.
- Work on a copy or a separate overlay. Preserve the captured pixels beneath the
  annotation; use an editor, SVG/browser overlay, or an existing image tool rather
  than regenerating the screenshot. Flatten overlays into an image for PR upload.

With ImageMagick 7, this example outlines one region; choose coordinates for the
actual capture and number it with a caption or your editor's text tool:

```sh
magick after-desktop.png -fill none -stroke '#2563eb' -strokewidth 3 \
  -draw 'rectangle 12,132 280,167' annotated-desktop.png
```

Use a tool already available on the machine or in the project. Installing software
or adding a dependency just for this evidence needs the user's approval. If no
annotation tool is available, publish the clearest labeled before/after pair with
specific captions and explain the limitation.

## Publish the comparison

Lead the PR's visual evidence with the annotated after capture and numbered
captions. Attach or link the original before and after captures in the same
comment; keep supporting captures in expandable details when they distract.
Label the compared revisions, route/state, viewport, and alignment limits.
A historical example names its original revisions and is a presentation trial,
not fresh verification of that PR.

Inspect the source captures and final annotation for private data, unrelated
screen content, error pages, and loading placeholders before publication.
Follow the [capture upload procedure](https://github.com/shakacode/shaka/blob/main/docs/pr-verification.md#show-what-a-person-will-see),
then read the comment back to confirm uploaded URLs. After a material change,
refresh affected captures, annotations, and any diagnostic images, or explain
which evidence remains applicable.

## Optional pixel diagnostics

An exact difference can help investigate subtle color or opacity changes and
unexpected differences outside callouts. Put it in expandable diagnostic details
beside its source captures, with an explanation of what it helps inspect.

Generate one when captures show the same rendered state at the same size.
ImageMagick still produces a result for different sizes; check the printed sizes
before comparing:

```sh
magick identify -format '%f %wx%h\n' before-desktop.png after-desktop.png
magick compare -metric AE before-desktop.png after-desktop.png diff-desktop.png
```

`compare` fades unchanged pixels and paints changed ones red. It prints the changed
pixel count and exits 1 when images differ; an error also needs inspection.
Moved text, antialiasing, and rendering noise can dominate the result.

When near-identical colors obscure a useful comparison, an additional image made
with `-fuzz 2%` can reduce noise. Label it filtered and retain the exact comparison:
a filtered image can hide a subtle change. Neither changed-pixel counts nor
annotations establish correctness or replace the manual pass and tests.
