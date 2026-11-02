// Test helper for I5a: makes process.arch report FAKE_ARCH, so the
// architecture mapping can be checked without an emulated platform.
// Loaded with NODE_OPTIONS=--require. It is never part of the image.
if (process.env.FAKE_ARCH) {
  Object.defineProperty(process, 'arch', { value: process.env.FAKE_ARCH });
}
