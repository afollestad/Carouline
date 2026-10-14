## Storage

- Write a new image, save the JSON that refers to it, and only then delete the file it replaced. A crash in between then leaves an orphan the launch sweep removes, never a project pointing at nothing.
- Sweep only in `loadAll()`, before anything can change a project: it deletes images no saved project refers to yet.
- Address a copy only by its `PlacedImage.fileName`, whose extension follows its format, and list every image a project refers to in `Project.images`, or the launch sweep deletes it.
- Go through `ProjectStore` for every write, since its tombstones stop a late save or import from recreating a deleted project.
- Never delete a project folder whose `project.json` failed to decode or has a newer `formatVersion`; list it as unreadable so the user decides.
- Bump `ProjectFile.currentFormatVersion` only for a change an older build would misread, migrate the previous shape in `decode(_:)`, and keep a golden JSON test for every version.
