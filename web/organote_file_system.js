(function () {
  let rootHandle = null;
  let rootLoaded = false;
  const dbName = "organote-file-system";
  const storeName = "handles";
  const rootKey = "root";

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

  function isMobileBrowser() {
    const userAgent = navigator.userAgent || "";
    return Boolean(
      (navigator.userAgentData && navigator.userAgentData.mobile) ||
        /Android|iPhone|iPad|iPod/i.test(userAgent)
    );
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

  function openDb() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open(dbName, 1);
      request.onupgradeneeded = () => {
        request.result.createObjectStore(storeName);
      };
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }

  async function storeRootHandle(handle) {
    if (!window.indexedDB) {
      return;
    }
    let db = null;
    try {
      db = await openDb();
      await new Promise((resolve, reject) => {
        const tx = db.transaction(storeName, "readwrite");
        tx.objectStore(storeName).put(handle, rootKey);
        tx.oncomplete = resolve;
        tx.onerror = () => reject(tx.error);
        tx.onabort = () => reject(tx.error);
      });
    } catch (_) {
      // The selected real folder remains usable for this session even if
      // browser handle persistence is unavailable.
    } finally {
      if (db) {
        db.close();
      }
    }
  }

  async function loadRootHandle() {
    if (rootLoaded) {
      return rootHandle;
    }
    rootLoaded = true;
    if (!window.indexedDB) {
      return null;
    }
    try {
      const db = await openDb();
      try {
        rootHandle = await new Promise((resolve, reject) => {
          const tx = db.transaction(storeName, "readonly");
          const request = tx.objectStore(storeName).get(rootKey);
          request.onsuccess = () => resolve(request.result || null);
          request.onerror = () => reject(request.error);
        });
        return rootHandle;
      } finally {
        db.close();
      }
    } catch (_) {
      rootHandle = null;
      return null;
    }
  }

  async function rootPermission() {
    const handle = await loadRootHandle();
    if (!handle) {
      return "missing";
    }
    if (!handle.queryPermission) {
      return "granted";
    }
    return handle.queryPermission({ mode: "readwrite" });
  }

  async function requestRootPermission() {
    const handle = await loadRootHandle();
    if (!handle) {
      return "missing";
    }
    if (!handle.requestPermission) {
      return "granted";
    }
    return handle.requestPermission({ mode: "readwrite" });
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
        !isMobileBrowser() &&
          window.isSecureContext &&
          window.showDirectoryPicker &&
          window.FileSystemDirectoryHandle &&
          FileSystemDirectoryHandle.prototype.entries
      );
    },
    supportMessage() {
      if (!window.isSecureContext) {
        return "Folder access requires HTTPS or localhost.";
      }
      if (isMobileBrowser()) {
        return "Mobile browsers do not expose folder access. Use desktop Chrome or Edge for Organote Web.";
      }
      return "This browser does not expose the File System Access API. Use desktop Chrome or Edge.";
    },
    rootName() {
      return rootHandle ? rootHandle.name : "";
    },
    async restoreRoot() {
      const handle = await loadRootHandle();
      return handle ? handle.name : "";
    },
    rootPermission,
    requestRootPermission,
    async chooseRoot() {
      rootHandle = await window.showDirectoryPicker({ mode: "readwrite" });
      rootLoaded = true;
      await storeRootHandle(rootHandle);
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
