// Realistic names for the live preview and the landing page's terminal: a pod
// name as a Deployment makes them, and a node for each pod. No dependencies,
// so the landing page can use them without loading Handlebars.
const letters = 'bcdfghjklmnpqrstvwxz2456789';
function pick(seed, length) {
  let value = '';
  let n = seed;
  for (let i = 0; i < length; i++) {
    n = (n * 1103515245 + 12345) % 2147483648;
    value += letters[n % letters.length];
  }
  return value;
}

export function podName(release, index) {
  return `hello-kubernetes-${release}-${pick(7, 10)}-${pick(index + 11, 5)}`;
}

export function nodeName(index) {
  return `worker-${(index % 3) + 1}`;
}
