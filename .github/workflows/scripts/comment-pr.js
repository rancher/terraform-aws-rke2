export default async ({ github, context }) => {
  const { owner, repo } = context.repo;
  const issue_number = context.issue.number || context.payload.pull_request?.number;
  const runUrl = `${context.serverUrl}/${owner}/${repo}/actions/runs/${context.runId}`;
  
  const status = process.env.COMMENT_STATUS;

  let body = '';
  if (status === 'wait') {
    body = `**E2E Tests Running...** Please wait while the end-to-end tests complete execution.\n\n[View test run](${runUrl})`;
  } else if (status === 'pass') {
    body = `**E2E Tests Passed!** The infrastructure tests have completed successfully.`;
  } else {
    throw new Error(`Unknown COMMENT_STATUS: ${status}`);
  }

  await github.rest.issues.createComment({
    owner,
    repo,
    issue_number,
    body
  });
};
