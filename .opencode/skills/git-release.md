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
        1. Updates `Project.swift` (increments `buildVersionString` or sets new `shortVersionString`).
        2. Generates new `CHANGELOG.md` entry from recent commits.
        3. Creates a local git commit with message format `ci(release_sh): VERSION-BUILD`.

        Post-Action:
        - Create a branch which name based on current commits and push it.
        - Create a PR.
        - Enable auto-merge of the PR.
        - Output summary.
    </instructions>

</skill>
