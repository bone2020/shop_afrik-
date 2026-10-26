/*
 * Refuses to let a script touch anything but staging or the emulator, so a
 * test-data script can never write into the real KartAfrik project.
 *
 * The Admin SDK can take its project from several places (FIREBASE_CONFIG,
 * the service-account key file, GOOGLE_CLOUD_PROJECT, GCLOUD_PROJECT), so
 * every one that is set must name an allowed project.
 */
const fs = require('fs');

const allowed = (project) => project === 'kartafrik-staging' || project.startsWith('demo-');

function readJson(text) {
  try {
    return JSON.parse(text);
  } catch {
    return undefined;
  }
}

/** Every project ID the Admin SDK could end up using, with where it came from. */
function projectSources(env = process.env) {
  const sources = [];
  const config = env.FIREBASE_CONFIG;
  if (config) {
    const parsed = readJson(config.trim().startsWith('{') ? config : fs.readFileSync(config, 'utf8'));
    sources.push(['FIREBASE_CONFIG', parsed?.projectId]);
  }
  if (env.GOOGLE_APPLICATION_CREDENTIALS) {
    const key = readJson(fs.readFileSync(env.GOOGLE_APPLICATION_CREDENTIALS, 'utf8'));
    if (key?.type === 'service_account') sources.push(['the deploy key', key.project_id]);
  }
  if (env.GOOGLE_CLOUD_PROJECT) sources.push(['GOOGLE_CLOUD_PROJECT', env.GOOGLE_CLOUD_PROJECT]);
  if (env.GCLOUD_PROJECT) sources.push(['GCLOUD_PROJECT', env.GCLOUD_PROJECT]);
  return sources;
}

/** Returns the staging project ID, or stops the script if any source points elsewhere. */
function stagingProjectId(env = process.env) {
  const sources = projectSources(env);
  const bad = sources.filter(([, project]) => !project || !allowed(project));
  if (sources.length === 0 || bad.length > 0) {
    const detail = sources.length === 0
      ? 'no project is set'
      : bad.map(([from, project]) => `${from} is "${project ?? '(unreadable)'}"`).join(', ');
    console.error(
      `Refusing to run: ${detail}. ` +
        'Set GCLOUD_PROJECT=kartafrik-staging (or a demo- emulator project).',
    );
    process.exit(1);
  }
  return sources[0][1];
}

module.exports = { stagingProjectId };
