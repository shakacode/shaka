# Make a difference image

Use the image tool the project already has. With ImageMagick 7, confirm the two
captures have the same size, then write the difference:

```sh
magick identify -format '%f %wx%h\n' before-desktop.png after-desktop.png
magick compare -metric AE -fuzz 2% before-desktop.png after-desktop.png diff-desktop.png
```

Compare the printed sizes yourself. `compare` still produces a result for images
of different sizes, and that result misleads the reviewer.

`compare` fades unchanged pixels and paints changed ones red. It prints the changed
pixel count and exits with status 1 when the images differ, so allow that exit in
scripts. `-fuzz 2%` ignores near-identical colors from antialiasing.

Attach the difference beside its source captures in one PR comment, as with any
capture. Put the label in the comment text or alt text; ImageMagick's `montage`
labels need a configured font and fail on some machines.
