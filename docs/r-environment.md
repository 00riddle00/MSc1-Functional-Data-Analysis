<!-- vim: set ft=markdown tw=88 nu ai et ts=2 sw=2: -->

# Preserving and Using the R 4.5.3 Environment

This document describes the reproducible R environment for the Functional Data
Analysis project.

The project was developed and tested with **R 4.5.3**. The host machine does not need
to remain on that version. A Podman image preserves R 4.5.3, the locked R packages and
the Linux system libraries required to build them, while the host can continue using a
newer R release for current projects.

The intended split is:

```text
Host system
├── current R version for new projects
├── editor, Git, file browser and PDF viewer
│
└── Podman image: fda-r:4.5.3
    ├── R 4.5.3
    ├── project R package library
    ├── compiler toolchain
    └── required Linux system libraries
```

The container is therefore a preserved **execution environment**, not a replacement
desktop environment.

## Why this exists

The original project was restored successfully with R 4.5.3 and the versions recorded
in `renv.lock`. Moving the host to R 4.6.x is useful for newer projects, but repeatedly
downgrading and upgrading the system R installation is unnecessary and fragile.

`renv` solves R package isolation, but it does not install or manage the R interpreter
itself. It also does not preserve system-level build dependencies such as Fortran,
libuv, GMP or the other development libraries required by compiled R packages.

The Podman image preserves all three layers:

1. R 4.5.3.
2. The R package versions described by `renv.lock`.
3. The Linux compiler and development libraries needed to build those packages.

The host can therefore continue to upgrade R independently.

## Final design

The repository uses:

```text
Dockerfile
.dockerignore
renv.lock
.Rprofile
renv/activate.R
renv/settings.json
```

The final image is named:

```text
localhost/fda-r:4.5.3
```

The Dockerfile intentionally starts from:

```dockerfile
FROM docker.io/rocker/r-ver:4.5.3
```

The image is built with Podman, but the conventional `Dockerfile` and `.dockerignore`
names are used for portability and recognizability. Docker itself is not required.

## Why Podman and `crun`

The environment was tested with rootless Podman on Arch Linux.

The initial rootless setup using `runc` failed while configuring cgroups. Installing
`crun` resolved the problem, including normal container runs without disabling
cgroups. The commands in this guide therefore specify the runtime explicitly:

```text
--runtime=crun
```

On Arch Linux:

```bash
sudo pacman -S podman crun
```

Do not refresh the package databases with `pacman -Sy` and then install individual
packages. Normal Arch package-management rules still apply.

## Build the image

Run from the repository root:

```bash
podman build --runtime=crun   -t fda-r:4.5.3   .
```

The first build is slow. Many packages in this project are compiled from source, and a
full restore can take well over ten minutes.

A successful build ends by tagging the image as:

```text
localhost/fda-r:4.5.3
```

Check that it exists:

```bash
podman image exists localhost/fda-r:4.5.3
echo $?
```

Exit status `0` means the image exists.

List relevant images with:

```bash
podman images | rg 'fda|rocker'
```

## Verify R itself

Check the R version inside the image:

```bash
podman run --rm   --runtime=crun   localhost/fda-r:4.5.3   R --version
```

It should report R 4.5.3 regardless of the R version installed on the host.

For example, the host may use R 4.6.x while this command still runs R 4.5.3.

## Verify the actual project environment

A bare `renv::status()` inside the image build directory is not the most useful check.
The image itself contains only the lockfile and `renv` bootstrap files under
`/opt/fda`; it does not contain the full project source tree. Without the source files,
`renv` cannot correctly determine which recorded packages are used by the project.

Perform the meaningful check by bind-mounting the real repository:

```bash
podman run --rm   --runtime=crun   -v "${PWD}:/opt/fda"   -w /opt/fda   localhost/fda-r:4.5.3   Rscript -e 'renv::status()'
```

The expected result is:

```text
No issues found -- the project is in a consistent state.
```

Run this command from the repository root.

## How the bind mount works

The important option is:

```bash
-v "${PWD}:/opt/fda"
```

It bind-mounts the real host repository into the container:

```text
Host                              Container
project repository     <---->     /opt/fda
```

These are the same files, not copies.

Consequences:

- editing a file on the host immediately changes the file seen by the container;
- output created by R under `/opt/fda` immediately appears on the host;
- generated PDFs, CSVs, RDS files and other outputs persist after the container exits;
- Git remains a normal host-side workflow;
- deleting a temporary container does not delete the project files.

The container isolates the runtime environment, not the project working tree.

## Recommended day-to-day workflow

The preferred workflow is:

```text
host editor
    ↓
edit files in the normal Git working tree
    ↓
run R commands through Podman
    ↓
outputs are written back into the same working tree
    ↓
inspect with host tools
    ↓
git diff / git add / git commit on the host
```

For example:

```bash
nvim EDA/Smoothing_and_EDA.R
```

Then run the edited script using R 4.5.3:

```bash
podman run --rm   --runtime=crun   -v "${PWD}:/opt/fda"   -w /opt/fda   localhost/fda-r:4.5.3   Rscript EDA/Smoothing_and_EDA.R
```

Then inspect the normal repository:

```bash
git status
git diff
```

There is normally no reason to edit files or create Git commits from inside the
container.

## Run another R script

Use the same pattern for any R script:

```bash
podman run --rm   --runtime=crun   -v "${PWD}:/opt/fda"   -w /opt/fda   localhost/fda-r:4.5.3   Rscript HT/Hypothesis_testing_ADHD.R
```

or:

```bash
podman run --rm   --runtime=crun   -v "${PWD}:/opt/fda"   -w /opt/fda   localhost/fda-r:4.5.3   Rscript REG/FDA_regression.R
```

## Run a one-off R expression

For example:

```bash
podman run --rm   --runtime=crun   -v "${PWD}:/opt/fda"   -w /opt/fda   localhost/fda-r:4.5.3   Rscript -e 'packageVersion("fda")'
```

or:

```bash
podman run --rm   --runtime=crun   -v "${PWD}:/opt/fda"   -w /opt/fda   localhost/fda-r:4.5.3   Rscript -e 'renv::status()'
```

## Open an interactive shell

For several commands in one session:

```bash
podman run --rm -it   --runtime=crun   -v "${PWD}:/opt/fda"   -w /opt/fda   localhost/fda-r:4.5.3   bash
```

Inside the container:

```bash
R --version
R
Rscript EDA/Smoothing_and_EDA.R
```

The project is available at:

```text
/opt/fda
```

Exit with:

```bash
exit
```

Because the container was started with `--rm`, that temporary container is removed
after it exits. The image and the bind-mounted project files remain.

## Running Make targets

The image includes the compiler toolchain and `make`, so R-oriented targets can be run
inside the container when their prerequisite files already exist:

```bash
make eda
make hypothesis_testing
make regression
```

Do not assume that the image can run the entire project from an empty checkout with
`make all`.

The image is intentionally focused on the preserved R environment. Earlier pipeline
steps use Python, Jupyter and DataLad, while the presentation/report stages use a larger
LaTeX toolchain. Those are still handled by the normal host/project setup.

## Running a long-lived development container

The normal workflow uses short-lived containers with `--rm`, which is simple and leaves
no stopped containers behind.

If a persistent shell is preferred, create a named container:

```bash
podman run -dit   --name fda   --runtime=crun   -v "${PWD}:/opt/fda"   -w /opt/fda   localhost/fda-r:4.5.3   sleep infinity
```

Enter it with:

```bash
podman exec -it fda bash
```

Stop and remove it when finished:

```bash
podman stop fda
podman rm fda
```

This is optional. Short-lived `podman run --rm ...` commands are simpler for most work.

## Generated files and Git status

The bind-mounted repository is writable.

Running the analysis can therefore regenerate tracked outputs. During the environment
recovery test, running the full pipeline regenerated many PDFs and executed notebooks
in place. Even visually identical PDFs can differ at the binary level because metadata,
object ordering or other generated data changes.

After reproducibility tests, check:

```bash
git status --short
git diff --stat
```

Do not assume that a large set of modified PDFs means the source analysis changed.

If generated tracked files were changed only as a test and should not be kept, review
the changes and restore them with Git.

Be especially careful with commands that execute notebooks in place: notebook outputs,
execution counts and metadata can produce very large diffs.

## Why the R package library lives outside `/opt/fda`

The Dockerfile sets:

```text
RENV_PATHS_LIBRARY=/opt/fda-library
```

During the image build, the restored packages are installed under that location.

At runtime, `/opt/fda` is replaced by the bind-mounted host repository. If the package
library were stored under `/opt/fda`, the bind mount would hide the library that was
built into the image.

Keeping it under `/opt/fda-library` allows the real project tree and the image's R
package library to coexist.

When R starts from `/opt/fda`, the project's `.Rprofile` and `renv/activate.R` activate
the project environment.

## System packages encoded in the image

The Dockerfile installs the Linux tools and development libraries required during the
successful restore, including:

```text
build-essential
gfortran
git
cmake
pkg-config
curl
libcurl4-openssl-dev
libssl-dev
libxml2-dev
libfontconfig1-dev
libharfbuzz-dev
libfribidi-dev
libfreetype6-dev
libpng-dev
libtiff-dev
libjpeg-dev
libwebp-dev
libicu-dev
libuv1-dev
libgmp-dev
libx11-dev
pandoc
```

Some of these were discovered during the restore:

- `libuv1-dev` was needed to build `fs`;
- `libgmp-dev` was needed to build `gmp`;
- `curl` removed an `renv` download-tool warning;
- `libx11-dev` and `pandoc` were reported as required system packages for packages such
  as `clipr`, `knitr`, `reprex` and `rmarkdown`;
- `gfortran` is required by several compiled statistical packages.

Encoding them in the Dockerfile avoids relying on whatever happens to be installed on
the host.

## Why `stringr` is restored first

The Dockerfile intentionally restores `stringr` before the complete restore:

```dockerfile
RUN Rscript -e 'renv::restore(packages = "stringr", prompt = FALSE)'
RUN Rscript -e 'renv::restore(prompt = FALSE)'
```

Without the targeted first step, the restore attempted to install `selectr` before
`stringr` was available:

```text
ERROR: dependency 'stringr' is not available for package 'selectr'
```

That caused downstream failures in `rvest` and `tidyverse`.

Restoring `stringr` first resolved the ordering problem. This line is therefore
intentional and should not be removed merely because a later build appears healthy.

## Why `future` is restored again

During the full restore, dependency repair installed:

```text
future 1.80.0
```

while the project's lockfile records:

```text
future 1.70.0
```

The Dockerfile therefore performs one final targeted restore:

```dockerfile
RUN Rscript -e 'renv::restore(packages = "future", prompt = FALSE)'
```

This returns the installed package to the lockfile version.

After that correction, `renv::status()` against the bind-mounted real project reported:

```text
No issues found -- the project is in a consistent state.
```

## Do not snapshot merely because the build suggests it

During a successful restore, `renv` may print a message such as:

```text
The dependency tree was repaired during package installation:
- corpcor
- crs
- future
- gmp
- infomax
- whitening

Call `renv::snapshot()` to capture these dependencies in the lockfile.
```

Do not automatically run `renv::snapshot()` in response.

This is a preserved project, and `renv.lock` is the authoritative description of the
original package environment. Snapshot the project only when intentionally changing its
dependencies and after reviewing what would change.

## Why `.dockerignore` excludes the local R library

The build context excludes:

```text
.git/
.venv/
ds006018/
ds006018_per_stimuli/
ds006018_functional/
```

It also excludes the local `renv` library while keeping only the bootstrap files:

```text
renv/*
!renv/activate.R
!renv/settings.json
```

This matters for two reasons.

First, the raw and generated EEG datasets are very large and should not be sent into the
container build context.

Second, the local R package library was built for the host system. The container uses
an Ubuntu userland and must build its own package binaries rather than copying packages
compiled for Arch Linux.

## Why the project does not use an RStudio image

An RStudio Server image based on:

```dockerfile
FROM docker.io/rocker/rstudio:4.5.3
```

was tested and intentionally rejected for this workflow.

That image provides **RStudio Server**, which is accessed in a web browser. It does not
provide the customized native RStudio Desktop environment installed on the host.

The browser-based session had its own defaults, appearance and project/session behavior.
Using it would mean maintaining a second IDE environment merely to reach the
containerized R runtime.

Native RStudio Desktop on the host also cannot simply attach its R session to an
arbitrary R process running inside this Podman container.

The chosen design is therefore simpler:

```text
editing / Git / file browsing / PDF viewing    → host
R 4.5.3 execution                              → container
```

If native RStudio Desktop with R 4.5.3 is ever required again, use a separate
side-by-side native R 4.5.3 installation. That is a different concern from the
container used to preserve this project.

The final Dockerfile should use `rocker/r-ver:4.5.3`, not
`rocker/rstudio:4.5.3`.

## Removing an old RStudio experiment

If an experimental RStudio image or container still exists, inspect the current state:

```bash
podman ps -a
podman images | rg 'fda|rocker'
```

Temporary RStudio containers started with `--rm` disappear automatically after they
stop.

If the experimental image remains and is no longer wanted:

```bash
podman rmi localhost/fda-rstudio:4.5.3
```

The downloaded Rocker RStudio base image can also be removed if nothing else uses it:

```bash
podman rmi docker.io/rocker/rstudio:4.5.3
```

Do not use `--force` merely to make cleanup succeed. If Podman reports that an image is
still in use, inspect the remaining container first.

## Container versus image

An **image** is the reusable environment:

```text
localhost/fda-r:4.5.3
```

A **container** is a running or stopped instance created from that image.

Most commands in this guide use:

```text
--rm
```

which automatically removes the temporary container when its command finishes.

It does not remove:

- the `fda-r:4.5.3` image;
- the repository;
- files written into the bind-mounted repository.

Useful inspection commands:

```bash
podman ps
podman ps -a
podman images
```

## Rebuilding after image removal

The local Podman image is not stored in Git.

The reproducible source of the image is the repository configuration, especially:

```text
Dockerfile
.dockerignore
renv.lock
.Rprofile
renv/activate.R
renv/settings.json
```

If the image is removed, rebuild it from the repository root:

```bash
podman build --runtime=crun   -t fda-r:4.5.3   .
```

## Working on the project in the future

Normal source changes require no special procedure.

Use:

```text
edit on host
    ↓
run R 4.5.3 code in container
    ↓
inspect outputs on host
    ↓
commit with normal host Git
```

The host R version can continue moving forward independently.

If the project's R dependencies are intentionally changed, review and update
`renv.lock`, then rebuild the image. Do not upgrade the preserved dependency set merely
to make it match the host's current R installation.

## Native R remains possible

The container does not prohibit a native setup.

If R 4.5.3 is installed directly on the host and the project-specific `renv` library is
restored, the project can still be run natively. That setup was successfully used while
recovering the project.

The reason for keeping the container is stronger long-term isolation: it preserves the
interpreter and Linux build dependencies as well as the R package versions.

For day-to-day new projects, the host can use the current R version and a fresh `renv`
environment without affecting this project.
