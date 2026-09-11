---
name: init-gcloud-config
description: Give the current project its own isolated gcloud config directory (account, project, zone) selected automatically by mise via CLOUDSDK_CONFIG. Use when the user runs /init-gcloud-config, asks to set up gcloud for this project, or wants gcloud to use a specific Google account, project, or VM here without affecting other directories.
---

## What this does

Writes `mise.local.toml` with `CLOUDSDK_CONFIG` pointing at a project-local `.gcloud/` directory, seeds it with the account, project, and default zone, and hands the user the one interactive step (login).

## Why a separate directory, not a named configuration

gcloud's own answer to per-project settings is named configurations plus `CLOUDSDK_ACTIVE_CONFIG_NAME`. They share one credential store under `~/.config/gcloud`, and `gcloud auth login` or `gcloud config set` always writes into whichever configuration is active. Two directories that resolve to the same configuration (or one directory with no override, which falls through to the global active one) silently clobber each other. That is how a `config set project` in one project leaked into another here.

`CLOUDSDK_CONFIG` moves the entire store: credentials, configurations, and Application Default Credentials live under the project's `.gcloud/`, so nothing done in any other directory can reach it. The cost is one `gcloud auth login` per project instead of per account. `.gcloud/` and `mise.local.toml` are both covered by `~/.gitignore_global`.

## Steps

1. **Confirm the directory is a project root** (`.git/`, `package.json`, `mise.toml`, etc.). Ask if unclear.

2. **Gather what the project already uses before touching anything.** Look for existing hints first, then ask the user one round of questions (AskUserQuestion, or plain prose in Codex) covering everything at once:

    - Existing state: `mise.local.toml`, `.gcloud/`, `.envrc`, and any `CLOUDSDK_*` in `.env.local`. Also `rg -n -- '--project|--zone|--region|CLOUDSDK|GOOGLE_CLOUD_PROJECT|gcloud ' -g '!node_modules'` across deploy scripts, `Makefile`/`justfile`, `cloudbuild.yaml`, `app.yaml`, Terraform, and GitHub workflows. Present what was found as the default answers.
    - **Account**: which Google account (email). Offer the credentialed ones from the shared store (`gcloud auth list`).
    - **Project**: the **project ID**, not the display name; they differ (`bl-sandbox` displays for ID `bl-sandbox-446517`). Offer candidates with `CLOUDSDK_CORE_ACCOUNT=<email> gcloud projects list --format='table(projectId,name)'`. If the account has no shared-store credentials the listing fails; ask for the ID directly.
    - **Key components already in use**: the VMs, Cloud Run services, GKE clusters, buckets, Cloud SQL instances, or functions this project talks to. These decide the default zone/region and confirm the project ID is right. Ask by name; do not guess from the repo alone.

    Do not write anything until the user has confirmed account, project ID, and components.

3. **Resolve zone and region from the components.** For a VM:

    ```sh
    CLOUDSDK_CORE_ACCOUNT=<email> gcloud compute instances list --project <project-id> --format='table(name,zone,status)'
    ```

    For Cloud Run, `gcloud run services list`; for GKE, `gcloud container clusters list`; both print the region. If components span several regions, pick the one the user names as primary and say so in the report. With no components, leave zone and region unset.

4. **If `mise.local.toml` already exists**, read it and merge; never overwrite other keys. Write:

    ```toml
    [env]
    CLOUDSDK_CONFIG = "{{config_root}}/.gcloud"
    ```

5. **Seed the store.** These work without credentials in the new store:

    ```sh
    export CLOUDSDK_CONFIG=<abs project root>/.gcloud
    gcloud config set account <email>
    gcloud config set project <project-id>
    ```

    `compute/zone` and `compute/region` validate against the API and fail before login; set them in step 7.

6. **Login is the user's step.** Tell them to run, in their own terminal (not the `!` prefix; it cannot answer the browser flow):

    ```sh
    cd <project root>
    gcloud auth login
    ```

    mise exports `CLOUDSDK_CONFIG` on entering the directory, so no env prefix is needed. If mise warns the config is untrusted, `mise trust` once.

7. **After login**, set the zone and verify:

    ```sh
    gcloud config set compute/zone <zone>
    gcloud config set compute/region <zone minus the -x suffix>
    gcloud auth list
    gcloud compute instances list
    ```

    From an agent session, prefix commands with `CLOUDSDK_CONFIG=<abs path>/.gcloud` when the session's shell was not started inside the project.

## Do not

- Do not use `gcloud config set` or `gcloud auth login` without `CLOUDSDK_CONFIG` set; it edits the global active configuration.
- Do not point two projects at the same `.gcloud/` directory.
- Do not write `.gcloud/` or `mise.local.toml` to a repo's `.gitignore`; the global gitignore covers both.
