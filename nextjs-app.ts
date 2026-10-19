type NextjsAppConfig = {
  app: {
    slug: string;
    directory: string;
    "node-version": string;
    "install-command": string;
    "lint-command": string;
    "test-command": string;
    "build-command": string;
    "opennext-build-command": string;
    "smoke-test-command": string;
  };
  preview: {
    "aws-region": string;
  };
};

const config = {
  app: {
    slug: "deploy-aws",
    directory: ".",
    "node-version": "22",
    "install-command": "npm ci",
    "lint-command": "npm run lint",
    "test-command": "",
    "build-command": "",
    "opennext-build-command": "npm run opennext:build",
    "smoke-test-command": 'npm run test:smoke -- "$PREVIEW_URL"',
  },
  preview: {
    "aws-region": "eu-north-1",
  },
} satisfies NextjsAppConfig;

export default config;