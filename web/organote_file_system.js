(function () {
  let rootHandle = null;

  function normalizePath(path) {
    return String(path || "")
      .replaceAll("\\", "/")
      .split("/")
      .filter((part) => part && part !== ".")
      .join("/");
  }

  function assertSafe(parts) {
    if (parts.some((part) => part === "..")) {
      throw new Error("Path must stay inside storage");
    }
  }

  async function directoryFor(path, create) {
    if (!rootHandle) {
      throw new Error("No Organote storage folder selected");
    }
    const parts = normalizePath(path).split("/").filter(Boolean);
    assertSafe(parts);
    let handle = rootHandle;
    for (const part of parts) {
      handle = await handle.getDirectoryHandle(part, { create });
    }
    return handle;
  }

  async function parentAndName(path, createParent) {
    const parts = normalizePath(path).split("/").filter(Boolean);
    assertSafe(parts);
    const name = parts.pop();
    if (!name) {
      throw new Error("Expected a file or directory path");
    }
    const parent = await directoryFor(parts.join("/"), createParent);
    return { parent, name };
  }

  async function fileHandle(path, create) {
    const { parent, name } = await parentAndName(path, create);
    return parent.getFileHandle(name, { create });
  }

  async function readBytes(path) {
    const handle = await fileHandle(path, false);
    const file = await handle.getFile();
    return Array.from(new Uint8Array(await file.arrayBuffer()));
  }

  async function writeBytes(path, bytes) {
    const handle = await fileHandle(path, true);
    const writable = await handle.createWritable();
    await writable.write(new Uint8Array(bytes));
    await writable.close();
  }

  async function listFiles(relativeDirectory, recursive) {
    const basePath = normalizePath(relativeDirectory);
    const base = await directoryFor(basePath, false);
    const files = [];

    async function visit(directory, prefix) {
      for await (const [name, handle] of directory.entries()) {
        const relativePath = [prefix, name].filter(Boolean).join("/");
        if (handle.kind === "directory") {
          if (recursive) {
            await visit(handle, relativePath);
          }
          continue;
        }
        const file = await handle.getFile();
        files.push({
          relativePath,
          sizeBytes: file.size,
          modifiedAt: new Date(file.lastModified).toISOString(),
        });
      }
    }

    await visit(base, basePath);
    files.sort((a, b) => a.relativePath.localeCompare(b.relativePath));
    return files;
  }

  window.organoteFs = {
    isSupported() {
      return Boolean(
        window.isSecureContext &&
          window.showDirectoryPicker &&
          FileSystemDirectoryHandle.prototype.entries
      );
    },
    rootName() {
      return rootHandle ? rootHandle.name : "";
    },
    async chooseRoot() {
      rootHandle = await window.showDirectoryPicker({ mode: "readwrite" });
      return rootHandle.name;
    },
    async ensureStructure(directories) {
      for (const directory of directories) {
        await directoryFor(directory, true);
      }
    },
    async createDirectory(path) {
      await directoryFor(path, true);
    },
    listFiles,
    async exists(path) {
      try {
        const { parent, name } = await parentAndName(path, false);
        try {
          await parent.getFileHandle(name, { create: false });
          return true;
        } catch (_) {
          await parent.getDirectoryHandle(name, { create: false });
          return true;
        }
      } catch (_) {
        return false;
      }
    },
    async readText(path) {
      const handle = await fileHandle(path, false);
      const file = await handle.getFile();
      return file.text();
    },
    readBytes,
    async writeText(path, contents) {
      await writeBytes(path, new TextEncoder().encode(contents));
    },
    writeBytes,
    async deleteEntry(path, recursive) {
      const { parent, name } = await parentAndName(path, false);
      await parent.removeEntry(name, { recursive });
    },
    async move(fromPath, toPath) {
      const bytes = await readBytes(fromPath);
      await writeBytes(toPath, bytes);
      await this.deleteEntry(fromPath, false);
    },
  };
})();
