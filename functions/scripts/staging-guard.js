/*
 * Refuses to let a script touch anything but staging or the emulator, so a
 * test-data script can never write into the real KartAfrik project.
 */
function stagingProjectId() {
  const project = process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
  const ok = !!project && (project.includes('staging') || project.startsWith('demo-'));
  if (!ok) {
    console.error(
      `Refusing to run against project "${project ?? '(not set)'}". ` +
        'Set GCLOUD_PROJECT=kartafrik-staging (or a demo- emulator project).',
    );
    process.exit(1);
  }
  return project;
}

module.exports = { stagingProjectId };
