export default {
  // Lint and auto-fix only the staged TS files.
  '{apps,libs,test}/**/*.ts': 'eslint --fix',
  // Format all staged files regardless of type.
  '*': 'prettier --write --ignore-unknown',
}
