// Handle EPIPE errors on stdout/stderr to prevent crashes when
// the app is launched without a terminal (e.g., from Finder on macOS)
// and the output pipes are closed.
function handlePipeError(err: NodeJS.ErrnoException) {
  if (err.code === 'EPIPE') return;
  throw err;
}
process.stdout.on('error', handlePipeError);
process.stderr.on('error', handlePipeError);

import './main';