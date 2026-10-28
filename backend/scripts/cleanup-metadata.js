require("dotenv").config();

const { removeSystemMetadataFilesFromDirectory } = require("../images/filesystem");

const directories = process.argv.slice(2);
if (directories.length === 0) {
  console.error("Usage: npm run cleanup:metadata -- <document-directory> [...directories]");
  process.exitCode = 1;
} else {
  (async () => {
    for (const directory of directories) {
      try {
        const removed = await removeSystemMetadataFilesFromDirectory(directory);
        console.log(JSON.stringify({ directory, removed }));
      } catch (error) {
        console.error(`Cleanup failed for ${directory}: ${error.message}`);
        process.exitCode = 1;
      }
    }
  })();
}
