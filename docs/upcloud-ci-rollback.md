# Temporary UpCloud Linux CI

Linux jobs use `[self-hosted, linux, x64, owllet-ci]` temporarily while hosted Actions capacity is exhausted. macOS jobs retain their existing hosted runners. Build, test, signing, release and deployment commands are unchanged.

Two repository-level runners run as `github-runner` on 95.111.222.17. Runner installations are `/opt/actions-runner-app` and `/opt/actions-runner-backend`; work directories and tool caches use `/mnt/owllet-ci`. A host-wide job-start hook holds a file lock until its Runner.Worker exits, serializing execution across both repositories. The server has 4 GB persistent swap.

## Rollback after hosted minutes reset

1. Change Linux declarations back to `runs-on: ubuntu-latest` and push through the normal review process.
2. Verify actual GitHub-hosted checks pass.
3. Deregister both repository runners from GitHub.
4. Stop and disable their `actions.runner.*` systemd services.
5. Remove the temporary VM only when no longer needed.

Do not perform rollback before hosted CI is verified. Do not change macOS jobs, branch protection, or required checks.
