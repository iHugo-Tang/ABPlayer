<skill>
    <name>git-release</name>
    <description>Prepares a new version for CI deployment: increments build version, updates changelog, and creates a release commit. Triggers the CI pipeline which handles the actual GitHub Release creation.</description>
    <when>
        when the user say:
        - git release
        - OR /git-release
        - OR when the user need perform a git-release action
    </when>
    <instructions>
        Run the release preparation script:
        `./scripts/release.sh [version]`

        Arguments:
        - `version` (optional): Specify exact version (e.g., "1.0.0"). If omitted, increments the build version automatically (e.g., 0.2.9-48 -> 0.2.9-49).

        Process:
        1. Use `git pull --rebase` to update codebase
        2. Updates `Project.swift` (increments `buildVersionString` or sets new `shortVersionString`).
        3. Generates new `CHANGELOG.md` entry from recent commits.
        4. Creates a local git commit with message format `ci(release_sh): VERSION-BUILD`.
        5. Create a branch which name based on current commits and push it.
        6. Create a PR.
        7. Enable auto-merge of the PR using `gh pr merge <CURRENT PR> --auto --merge`.
        8. Output summary.
    </instructions>

</skill>
