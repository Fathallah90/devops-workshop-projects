# Git Troubleshooting Guide

## Repository Maintenance, `.gitignore`, SSH Authentication, and WSL Filesystem Issues

This document records the Git issues encountered while maintaining the `devops-workshop-projects` repository, the commands used to diagnose them, and the solutions applied.

The goal is to understand not only how to fix Git problems but also why they happen.

---

# 1. Repository Status and Pre-Push Validation

## Problem

Before pushing changes to GitHub, we needed to verify that the repository was in a safe state.

We wanted to identify:

- Modified tracked files.
- New untracked files.
- Staged changes.
- Accidentally deleted files.
- Generated files that should not be committed.
- Local commits not yet pushed to GitHub.

## 1.1 Check repository status

```bash
git status
```

**Purpose:** Displays the current working-tree and staging-area status.

Important status indicators:

| Indicator | Meaning |
|---|---|
| `M` | Modified tracked file |
| `A` | Added file |
| `D` | Deleted tracked file |
| `??` | Untracked file |
| `R` | Renamed file |

Short format:

```bash
git status --short
```

**Purpose:** Displays a compact status for easier inspection.

Example:

```text
 M README.md
A  installation.md
?? test.txt
```

The two status columns have different meanings:

- First column: staging-area status.
- Second column: working-tree status.

For example, ` M` means the file is modified but not staged.

## 1.2 Inspect staged changes

```bash
git diff --cached --name-status
```

**Purpose:** Lists changes already staged for the next commit.

Useful for detecting accidental additions and deletions before committing.

To inspect the actual staged content:

```bash
git diff --cached
```

## 1.3 Inspect unstaged changes

```bash
git diff --name-status
```

**Purpose:** Lists modifications in the working tree that have not been staged.

To inspect the actual changes:

```bash
git diff
```

## 1.4 Check whitespace errors

```bash
git diff --check
```

**Purpose:** Detects whitespace errors in unstaged changes, including trailing whitespace and certain malformed lines.

For staged changes:

```bash
git diff --cached --check
```

## 1.5 Inspect a particular project directory

```bash
git status --short --ignored -- \
"1- lecture-projects/05-containerized-multi-tier-app/"
```

**Purpose:** Displays the status of files in a specific directory, including ignored files.

The `--` separates Git options from file paths.

The `--ignored` option also reveals files excluded by `.gitignore`.

---

# 2. `.gitignore` Troubleshooting

## Problem

We needed to ensure that generated files, credentials, Terraform state, Vagrant artifacts, and other temporary files were not accidentally committed.

We also needed to distinguish between:

- Files that are correctly ignored.
- Files that are already tracked by Git.
- Files that should be ignored only within a particular project.

## 2.1 Inspect ignore rules

```bash
cat .gitignore
```

**Purpose:** Displays the repository's root ignore rules.

For a project-specific ignore file:

```bash
cat "3- case-study-projects/01-aws-environment-terraform-ansible/.gitignore"
```

**Purpose:** Displays ignore rules specific to the AWS Terraform and Ansible project.

## 2.2 Identify which rule ignores a file

```bash
git check-ignore -v \
"3- case-study-projects/01-aws-environment-terraform-ansible/terraform/terraform.tfstate"
```

**Purpose:** Identifies the exact `.gitignore` file, line number, and pattern responsible for ignoring a file.

Example:

```text
.gitignore:9:*.tfstate
```

This means that the file is ignored because of the `*.tfstate` rule on line 9.

## 2.3 Check ignored files even if they are tracked

```bash
git check-ignore -v --no-index \
"3- case-study-projects/01-aws-environment-terraform-ansible/terraform/terraform.tfstate"
```

**Purpose:** Checks ignore rules without relying on the current index tracking status.

The `--no-index` option is useful when investigating whether a rule would ignore a file even if it is already tracked.

## 2.4 Important: `.gitignore` does not remove tracked files

If a file was committed previously, adding it to `.gitignore` does not automatically stop tracking it.

To stop tracking a specific file while keeping the local copy:

```bash
git rm --cached path/to/file
```

To stop tracking a directory while keeping its local contents:

```bash
git rm -r --cached path/to/directory
```

**Important:** These commands stage deletions from Git's index. Review the staged changes before committing.

Do not use these commands indiscriminately on directories containing important project files.

## 2.5 Inspect the staged deletion list

```bash
git diff --cached --name-status
```

**Purpose:** Verifies which files Git intends to delete, modify, or add in the next commit.

This is particularly important after modifying ignore rules.

---

# 3. Terraform and Vagrant Generated Files

## Problem

Terraform and Vagrant generate files that should generally not be committed to a source-code repository.

Examples include:

- Terraform state files.
- Terraform provider binaries.
- Terraform working directories.
- Vagrant machine metadata.
- Vagrant logs.
- Virtual machine disks.

## 3.1 Terraform files to ignore

Typical patterns:

```gitignore
.terraform/
*.tfstate
*.tfstate.*
*.tfplan
crash.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
```

**Explanation:**

| Pattern | Purpose |
|---|---|
| `.terraform/` | Terraform working directory and downloaded providers |
| `*.tfstate` | Terraform state files |
| `*.tfstate.*` | State backups and related files |
| `*.tfplan` | Saved execution plans |
| `crash.log` | Terraform crash logs |
| `override.tf` | Local override configuration |

Terraform state can contain sensitive infrastructure information and should be handled carefully.

## 3.2 Vagrant files to ignore

Typical patterns:

```gitignore
.vagrant/
*.box
vagrant-debug.log
```

**Explanation:**

- `.vagrant/` contains local machine metadata.
- `*.box` contains packaged Vagrant boxes.
- `vagrant-debug.log` contains diagnostic logs.

Do not ignore the actual `Vagrantfile` unless there is a specific reason.

---

# 4. Git Line Endings: Windows, WSL, and Linux

## Problem

The repository is accessed from WSL through a Windows-mounted drive:

```text
/mnt/f/DevOps_Workshop/My_Github_Repo/devops-workshop-projects
```

Files can be accessed from Windows, WSL, and Linux environments, so consistent line endings are important.

## 4.1 Inspect Git line-ending configuration

```bash
git config --show-origin --get core.autocrlf || true
git config --show-origin --get core.eol || true
```

**Purpose:** Displays the configured Git line-ending behavior.

The `|| true` prevents the shell from treating an unset configuration value as a command failure.

## 4.2 Inspect line-ending information

```bash
git ls-files --eol
```

**Purpose:** Shows the line-ending format recorded in the Git index and found in the working tree.

Common indicators:

| Indicator | Meaning |
|---|---|
| `i/lf` | Index contains LF |
| `i/crlf` | Index contains CRLF |
| `w/lf` | Working tree contains LF |
| `w/crlf` | Working tree contains CRLF |

## 4.3 Configure consistent line endings with `.gitattributes`

The repository uses:

```gitattributes
# Normalize text files to LF across Windows, WSL, and Linux
* text=auto eol=lf
```

**Explanation:**

- `text=auto`: Git detects text files and normalizes their line endings.
- `eol=lf`: Specifies LF line endings in the working tree.

This helps maintain consistency across different operating systems.

## 4.4 Validate file attributes

```bash
git check-attr text eol -- Dockerfile
```

**Purpose:** Shows the effective attributes applied to a file.

---

# 5. Git Whitespace and Content Validation

## Problem

We needed to determine whether Git was reporting actual file-content changes or only detecting differences in file metadata.

## 5.1 Check whether files have content differences

```bash
git diff --exit-code
```

**Purpose:** Checks whether the working tree differs from the index.

Exit codes:

| Exit code | Meaning |
|---|---|
| `0` | No content differences |
| `1` | Differences found |
| Other | An error occurred |

This command was important in our investigation because it confirmed that the working-tree content matched the index despite the modification markers.

## 5.2 Compare a specific file against the Git index

```bash
FILE="1- lecture-projects/05-containerized-multi-tier-app/Dockerfile"

git rev-parse ":$FILE"
```

**Purpose:** Displays the Git blob hash stored in the index for the file.

Compare it with:

```bash
git hash-object "$FILE"
```

**Purpose:** Calculates the Git blob hash of the current working-tree file without modifying it.

If both hashes match, the file's contents are identical to the version in the index.

Example from our troubleshooting:

```text
Index hash:
09b3f2c76b210536cd0ecceeec7b2111184c1909

Working-tree hash:
09b3f2c76b210536cd0ecceeec7b2111184c1909
```

The matching hashes proved that the Dockerfile's content had not changed.

---

# 6. Git Push Authentication: HTTPS vs SSH

## Problem

The initial push attempt over HTTPS failed because GitHub no longer accepts ordinary account passwords for Git authentication.

We switched the repository's remote to SSH authentication.

## 6.1 Inspect configured remotes

```bash
git remote -v
```

**Purpose:** Displays the configured remote repositories and their fetch/push URLs.

Example SSH remote:

```text
origin  git@github.com:Fathallah90/devops-workshop-projects.git (fetch)
origin  git@github.com:Fathallah90/devops-workshop-projects.git (push)
```

## 6.2 Check existing SSH keys

```bash
ls -la ~/.ssh/
```

**Purpose:** Lists SSH configuration and key files.

Common files:

```text
id_rsa
id_rsa.pub
known_hosts
config
```

- `id_rsa`: Private key.
- `id_rsa.pub`: Public key.
- `known_hosts`: Previously trusted SSH server identities.
- `config`: Optional SSH client configuration.

Never share your private key.

## 6.3 Display the public key

```bash
cat ~/.ssh/id_rsa.pub
```

**Purpose:** Displays the public key that can be added to your GitHub account.

Only the public key should be uploaded to GitHub.

## 6.4 Test SSH authentication

```bash
ssh -T git@github.com
```

**Purpose:** Tests SSH authentication with GitHub.

Successful output:

```text
Hi Fathallah90! You've successfully authenticated, but GitHub does not provide shell access.
```

This confirms that GitHub recognizes the SSH key.

## 6.5 Understand the first SSH connection prompt

The first connection may display:

```text
The authenticity of host 'github.com' can't be established.
```

SSH is asking whether you trust the server's host key.

Before accepting, verify the displayed fingerprint against GitHub's official published SSH fingerprints.

Once verified, accepting the connection stores the host key in `~/.ssh/known_hosts`.

## 6.6 Change the Git remote to SSH

```bash
git remote set-url origin \
git@github.com:Fathallah90/devops-workshop-projects.git
```

**Purpose:** Changes the remote URL from HTTPS to SSH.

Verify:

```bash
git remote -v
```

## 6.7 Push changes

```bash
git push origin main
```

**Purpose:** Pushes local `main` branch commits to the remote `origin/main` branch.

---

# 7. Git Repository Synchronization

## Problem

After successfully pushing changes, we wanted to confirm that the local repository and GitHub contained the same commits.

## 7.1 Fetch remote changes

```bash
git fetch origin
```

**Purpose:** Downloads remote branch and commit information without changing the working tree or merging changes.

## 7.2 Check branch synchronization

```bash
git status -sb
```

Example:

```text
## main...origin/main
```

**Purpose:** Displays the current branch and its relationship with the upstream branch.

## 7.3 Compare local and remote commits

```bash
git rev-list --left-right --count origin/main...HEAD
```

**Purpose:** Counts commits that exist on the remote but not locally, and commits that exist locally but not remotely.

Example:

```text
0       0
```

Meaning:

- First number: commits ahead on `origin/main` relative to local `HEAD`.
- Second number: commits ahead locally relative to `origin/main`.

Both zero means the branches contain the same commits.

## 7.4 Review recent commits

```bash
git log -3 --oneline --decorate
```

**Purpose:** Displays the three most recent commits in compact format.

Example:

```text
ee08968 (HEAD -> main, origin/main, origin/HEAD) Add repository and project-specific Git ignore rules
4dae7c8 Add initial Terraform configuration and Vagrant setup
```

The branch labels show that local `main` and remote `origin/main` point to the same commit.

---

# 8. WSL `/mnt/f` Filesystem: False Git Modification Markers

## Problem

After the commits were successfully pushed, Git continued reporting 62 modified files:

```text
 M .vscode/settings.json
 M 1- lecture-projects/01-multi-tier-java-on-premises/README.md
 M 1- lecture-projects/05-containerized-multi-tier-app/Dockerfile
...
```

However:

- The files were not intentionally modified.
- `git diff --check` did not report whitespace errors.
- `git diff --exit-code` confirmed there were no content differences.
- File hashes matched the Git index.
- The repository was stored on `/mnt/f`, a Windows-mounted filesystem accessed from WSL.

This indicated a Git index metadata problem rather than actual source-code changes.

## 8.1 Identify the filesystem type

```bash
df -T .
```

**Purpose:** Displays the filesystem type and storage information for the current directory.

Our output:

```text
Filesystem     Type
F:\            9p
```

This confirmed that the repository was on a Windows-mounted drive.

## 8.2 Inspect Git filesystem configuration

```bash
git config --show-origin --get core.filemode || true
git config --show-origin --get core.autocrlf || true
git config --show-origin --get core.eol || true
git config --show-origin --get core.trustctime || true
git config --show-origin --get core.checkStat || true
git config --show-origin --get core.fsmonitor || true
```

**Purpose:** Checks Git settings that influence filesystem metadata, file modes, timestamps, line endings, and filesystem monitoring.

Our repository had:

```text
core.filemode=false
```

The other queried settings were not explicitly configured.

## 8.3 Inspect the Git index metadata

```bash
git ls-files --debug -- "$FILE"
```

**Purpose:** Displays cached metadata for a tracked file.

Git stores information such as:

- Creation/change timestamp (ctime).
- Modification timestamp (mtime).
- Device and inode identifiers.
- File size.
- Index flags.

Our Dockerfile initially showed:

```text
ctime: 1794503926:19661300
mtime: 1794588080:690086200
dev: 0        ino: 0
uid: 0        gid: 0
size: 1158    flags: 0
```

But the actual file metadata showed:

```text
Size: 1113
```

The cached index metadata did not match the working-tree metadata.

## 8.4 Test whether ctime was responsible

```bash
git -c core.trustctime=false status --short
```

**Purpose:** Runs Git with ctime checking disabled for this command only.

The `-c` option applies a temporary configuration value without permanently modifying `.git/config`.

In our case, the 62 modification markers remained.

This indicated that disabling ctime alone was not sufficient.

## 8.5 Compare the actual file hashes

```bash
FILE="1- lecture-projects/05-containerized-multi-tier-app/Dockerfile"

git rev-parse ":$FILE"
git hash-object "$FILE"
```

**Purpose:** Compares the committed/index blob with the actual working-tree file content.

Both hashes matched, proving that the Dockerfile content was unchanged.

## 8.6 Inspect the actual filesystem metadata

```bash
stat "$FILE"
```

**Purpose:** Displays the working-tree file's size, permissions, ownership, timestamps, and filesystem identifiers.

This helped us identify the mismatch between the index metadata and actual file metadata.

## 8.7 Refresh one file's index metadata

```bash
git update-index --refresh -- "$FILE"
```

**Purpose:** Asks Git to refresh the cached metadata for the specified tracked file.

After the refresh, the Dockerfile's index metadata changed to reflect the actual working-tree file:

```text
dev: 71       ino: 2517
uid: 1000     gid: 1000
size: 1113    flags: 0
```

Its modification marker disappeared.

## 8.8 Refresh the remaining affected files

First, we confirmed that there were no actual unstaged content changes:

```bash
git diff --exit-code
echo "Exit code: $?"
```

After confirming exit code `0`, we refreshed the remaining affected index entries:

```bash
git diff-files --name-only -z |
while IFS= read -r -d '' file; do
    git update-index --refresh -- "$file" >/dev/null 2>&1 || true
done
```

**Command explanation:**

| Part | Purpose |
|---|---|
| `git diff-files` | Checks working-tree files against the index |
| `--name-only` | Returns only filenames |
| `-z` | Uses null separators to handle filenames safely |
| `while IFS= read -r -d '' file` | Reads each filename without breaking on spaces |
| `git update-index --refresh` | Refreshes the cached metadata for each file |
| `>/dev/null 2>&1` | Suppresses command output |
| `|| true` | Allows the loop to continue if an individual refresh reports a mismatch |

**Important:** This operation does not stage changes or commit files. It refreshes Git's index metadata.

The result was:

```text
Remaining modification markers: 0
```

All 62 false modification markers were resolved.

---

# 9. Final Repository Validation

After troubleshooting, we performed a final validation.

## 9.1 Check the working tree

```bash
git status --short
```

Expected result:

```text
```

No output means there are no staged or unstaged changes and no untracked files.

## 9.2 Check branch synchronization

```bash
git status -sb
```

Expected result:

```text
## main...origin/main
```

## 9.3 Compare local and remote commits

```bash
git rev-list --left-right --count origin/main...HEAD
```

Expected result:

```text
0       0
```

## 9.4 Review the latest commits

```bash
git log -3 --oneline --decorate
```

Final repository history:

```text
ee08968 (HEAD -> main, origin/main, origin/HEAD) Add repository and project-specific Git ignore rules
4dae7c8 Add initial Terraform configuration and Vagrant setup
9182c55 Remove MySQL and RabbitMQ password files for security reasons
```

## Final result

| Validation | Result |
|---|---|
| Working tree | Clean |
| Staging area | Clean |
| Untracked files | None |
| False modification markers | 0 |
| Local branch | `main` |
| Remote branch | `origin/main` |
| Commits ahead | 0 |
| Commits behind | 0 |
| SSH authentication | Successful |
| GitHub synchronization | Successful |

---

# 10. Recommended Git Pre-Push Checklist

Use this checklist before pushing future project changes.

```bash
# 1. Check current branch
git branch --show-current

# 2. Check working-tree status
git status --short

# 3. Review staged changes
git diff --cached --name-status

# 4. Review unstaged changes
git diff --name-status

# 5. Check whitespace errors
git diff --check
git diff --cached --check

# 6. Inspect ignored files when necessary
git status --short --ignored

# 7. Verify ignored files when necessary
git check-ignore -v --no-index path/to/file

# 8. Fetch remote updates
git fetch origin

# 9. Check synchronization
git status -sb
git rev-list --left-right --count origin/main...HEAD

# 10. Review recent commits
git log -5 --oneline --decorate
```

After reviewing the changes and confirming they are intended:

```bash
git add path/to/your/files
git diff --cached
git diff --cached --check
git commit -m "Describe your changes"
git push origin main
```

**Best practices:**

1. Prefer `git add path/to/file` over blindly using `git add .`.
2. Never commit Terraform state files, credentials, private keys, or generated provider binaries.
3. Use `.gitignore` for generated files and `.gitattributes` for consistent text-file handling.
4. Review staged deletions before committing.
5. Verify SSH authentication before troubleshooting GitHub push failures.
6. Fetch before comparing local and remote branches.
7. Never use `git reset --hard` or `git clean -fd` as a routine troubleshooting shortcut.
8. When working from WSL, understand the filesystem backing the repository.
9. Verify content hashes before concluding that a reported modification is a real source-code change.
10. Keep the working tree clean and the local branch synchronized with GitHub.

---

# 11. Useful Git Commands Reference

| Command | Description |
|---|---|
| `git status` | Show repository status |
| `git status -sb` | Show compact branch status |
| `git diff` | Show unstaged changes |
| `git diff --cached` | Show staged changes |
| `git diff --check` | Detect whitespace errors |
| `git diff --name-status` | List changed files |
| `git diff --cached --name-status` | List staged changes |
| `git check-ignore -v` | Identify the matching ignore rule |
| `git ls-files --eol` | Inspect line-ending formats |
| `git ls-files --debug` | Inspect index metadata |
| `git hash-object` | Calculate a Git blob hash |
| `git update-index --refresh` | Refresh cached index metadata |
| `git fetch origin` | Download remote references |
| `git remote -v` | Display remote URLs |
| `git log --oneline` | Display compact commit history |
| `git rev-list --left-right --count` | Compare local and remote commits |
| `git push origin main` | Push commits to GitHub |
| `ssh -T git@github.com` | Test GitHub SSH authentication |

---

**Learning takeaway:** Git does not track only file contents. It also maintains an index containing cached metadata to optimize comparisons. Understanding the working tree, staging area, Git index, repository history, ignore rules, and remote branches is essential for diagnosing Git problems safely.