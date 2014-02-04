module git.c.clone;

/*
 * Copyright (C) the libgit2 contributors. All rights reserved.
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */

/**
 * @file git2/clone.h
 * @brief Git cloning routines
 * @defgroup git_clone Git cloning routines
 * @ingroup Git
 * @{
 */

import git.c.checkout;
import git.c.common;
import git.c.indexer;
import git.c.remote;
import git.c.transport;
import git.c.types;

extern (C):

/**
 * Clone options structure
 *
 * Use zeros to indicate default settings.  It's easiest to use the
 * `GIT_CLONE_OPTIONS_INIT` macro:
 *
 *		git_clone_options opts = GIT_CLONE_OPTIONS_INIT;
 *
 * - `checkout_opts` is options for the checkout step.  To disable checkout,
 *   set the `checkout_strategy` to GIT_CHECKOUT_DEFAULT.
 * - `bare` should be set to zero to create a standard repo, non-zero for
 *   a bare repo
 * - `ignore_cert_errors` should be set to 1 if errors validating the remote host's
 *   certificate should be ignored.
 *
 *   ** "origin" remote options: **
 * - `remote_name` is the name given to the "origin" remote.  The default is
 *   "origin".
 * - `checkout_branch` gives the name of the branch to checkout. NULL means
 *   use the remote's HEAD.
 */

struct git_clone_options {
	uint version_ = GIT_CLONE_OPTIONS_VERSION;

	git_checkout_opts checkout_opts;
	git_remote_callbacks remote_callbacks;

	int bare;
	int ignore_cert_errors;
	const(char)* remote_name;
	const(char)* checkout_branch;
}

enum GIT_CLONE_OPTIONS_VERSION = 1;
enum git_clone_options GIT_CLONE_OPTIONS_INIT = { GIT_CLONE_OPTIONS_VERSION };

/**
 * Clone a remote repository.
 *
 * This version handles the simple case. If you'd like to create the
 * repository or remote with non-default settings, you can create and
 * configure them and then use `git_clone_into()`.
 *
 * @param out pointer that will receive the resulting repository object
 * @param url the remote repository to clone
 * @param local_path local directory to clone to
 * @param options configuration options for the clone.  If NULL, the function
 * works as though GIT_OPTIONS_INIT were passed.
 * @return 0 on success, GIT_ERROR otherwise (use giterr_last for information
 * about the error)
 */
int git_clone(
		git_repository **out_,
		const(char)* url,
		const(char)* local_path,
		const(git_clone_options)* options);

/**
 * Clone into a repository
 *
 * After creating the repository and remote and configuring them for
 * paths and callbacks respectively, you can call this function to
 * perform the clone operation and optionally checkout files.
 *
 * @param repo the repository to use
 * @param remote the remote repository to clone from
 * @param co_opts options to use during checkout
 * @param branch the branch to checkout after the clone, pass NULL for the remote's
 * default branch
 * @return 0 on success or an error code
 */
int git_clone_into(git_repository *repo, git_remote *remote, const(git_checkout_opts)* co_opts, const(char)* branch);

//#endif