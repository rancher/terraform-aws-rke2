export default async ({ github, context }) => {
  const today = new Date().toISOString().split('T')[0].replace(/-/g, '');
  const headBranch = `automation/update-go-deps-${today}`;
  const baseBranch = context.payload.repository.default_branch;

  console.log(`Creating pull request from ${headBranch} to ${baseBranch}`);

  try {
    const { data: pr } = await github.rest.pulls.create({
      owner: context.repo.owner,
      repo: context.repo.repo,
      title: 'chore(deps): automated go dependency updates',
      head: headBranch,
      base: baseBranch,
      body: `This is an automated pull request updating Go dependencies inside the \`test\` directory to their latest versions.

All automated compilation checks passed successfully (no live AWS infrastructure was provisioned).`,
      draft: false,
    });
    console.log(`Successfully created PR #${pr.number}: ${pr.html_url}`);
  } catch (error) {
    console.error('Error creating pull request:', error);
    throw error;
  }
};
