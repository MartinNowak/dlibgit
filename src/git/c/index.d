module git.c.index;

/*
 * Copyright (C) the libgit2 contributors. All rights reserved.
 *
 * This file is part of libgit2, distributed under the GNU GPL v2 with
 * a Linking Exception. For full terms see the included COPYING file.
 */

/**
 * @file git2/index.h
 * @brief Git index parsing and manipulation routines
 * @defgroup git_index Git index parsing and manipulation routines
 * @ingroup Git
 * @{
 */

import git.c.common;
import git.c.indexer;
import git.c.oid;
import git.c.strarray;
import git.c.types;

extern (C):

/** Time structure used in a git index entry */
struct git_index_time {
	git_time_t seconds;
	/* nsec should not be stored as time_t compatible */
	uint nanoseconds;
} ;

/**
 * In-memory representation of a file entry in the index.
 *
 * This is a public structure that represents a file entry in the index.
 * The meaning of the fields corresponds to core Git's documentation (in
 * "Documentation/technical/index-format.txt").
 *
 * The `flags` field consists of a number of bit fields which can be
 * accessed via the first set of `GIT_IDXENTRY_...` bitmasks below.  These
 * flags are all read from and persisted to disk.
 *
 * The `flags_extended` field also has a number of bit fields which can be
 * accessed via the later `GIT_IDXENTRY_...` bitmasks below.  Some of
 * these flags are read from and written to disk, but some are set aside
 * for in-memory only reference.
 */
struct git_index_entry {
	git_index_time ctime;
	git_index_time mtime;

	uint dev;
	uint ino;
	uint mode;
	uint uid;
	uint gid;
	git_off_t file_size;

	git_oid oid;

	ushort flags;
	ushort flags_extended;

	char *path;
} ;

/**
 * Bitmasks for on-disk fields of `git_index_entry`'s `flags`
 *
 * These bitmasks match the four fields in the `git_index_entry` `flags`
 * value both in memory and on disk.  You can use them to interpret the
 * data in the `flags`.
 */
enum GIT_IDXENTRY_NAMEMASK   = (0x0fff);
enum GIT_IDXENTRY_STAGEMASK  = (0x3000);
enum GIT_IDXENTRY_EXTENDED   = (0x4000);
enum GIT_IDXENTRY_VALID      = (0x8000);
enum GIT_IDXENTRY_STAGESHIFT = 12;

auto GIT_IDXENTRY_STAGE(T)(T E) { return (((E).flags & GIT_IDXENTRY_STAGEMASK) >> GIT_IDXENTRY_STAGESHIFT); }

/**
 * Bitmasks for on-disk fields of `git_index_entry`'s `flags_extended`
 *
 * In memory, the `flags_extended` fields are divided into two parts: the
 * fields that are read from and written to disk, and other fields that
 * in-memory only and used by libgit2.  Only the flags in
 * `GIT_IDXENTRY_EXTENDED_FLAGS` will get saved on-disk.
 *
 * These bitmasks match the three fields in the `git_index_entry`
 * `flags_extended` value that belong on disk.  You can use them to
 * interpret the data in the `flags_extended`.
 */
enum GIT_IDXENTRY_INTENT_TO_ADD     = (1 << 13);
enum GIT_IDXENTRY_SKIP_WORKTREE     = (1 << 14);
/* GIT_IDXENTRY_EXTENDED2 is reserved for future extension */
enum GIT_IDXENTRY_EXTENDED2         = (1 << 15);

enum GIT_IDXENTRY_EXTENDED_FLAGS = (GIT_IDXENTRY_INTENT_TO_ADD | GIT_IDXENTRY_SKIP_WORKTREE);

/**
 * Bitmasks for in-memory only fields of `git_index_entry`'s `flags_extended`
 *
 * These bitmasks match the other fields in the `git_index_entry`
 * `flags_extended` value that are only used in-memory by libgit2.  You
 * can use them to interpret the data in the `flags_extended`.
 */
enum GIT_IDXENTRY_UPDATE            = (1 << 0);
enum GIT_IDXENTRY_REMOVE            = (1 << 1);
enum GIT_IDXENTRY_UPTODATE          = (1 << 2);
enum GIT_IDXENTRY_ADDED             = (1 << 3);

enum GIT_IDXENTRY_HASHED            = (1 << 4);
enum GIT_IDXENTRY_UNHASHED          = (1 << 5);
enum GIT_IDXENTRY_WT_REMOVE         = (1 << 6); /* remove in work directory */
enum GIT_IDXENTRY_CONFLICTED        = (1 << 7);

enum GIT_IDXENTRY_UNPACKED          = (1 << 8);
enum GIT_IDXENTRY_NEW_SKIP_WORKTREE = (1 << 9);

/** Capabilities of system that affect index actions. */
enum git_indexcap_t {
	GIT_INDEXCAP_IGNORE_CASE = 1,
	GIT_INDEXCAP_NO_FILEMODE = 2,
	GIT_INDEXCAP_NO_SYMLINKS = 4,
	GIT_INDEXCAP_FROM_OWNER  = ~0u
} ;

/** Callback for APIs that add/remove/update files matching pathspec */
alias git_index_matched_path_cb = int function(
	const(char)* path, const(char)* matched_pathspec, void *payload);

/** Flags for APIs that add files matching pathspec */
enum git_index_add_option_t {
	GIT_INDEX_ADD_DEFAULT = 0,
	GIT_INDEX_ADD_FORCE = (1u << 0),
	GIT_INDEX_ADD_DISABLE_PATHSPEC_MATCH = (1u << 1),
	GIT_INDEX_ADD_CHECK_PATHSPEC = (1u << 2),
} ;

/** @name Index File Functions
 *
 * These functions work on the index file itself.
 */
/**@{*/

/**
 * Create a new bare Git index object as a memory representation
 * of the Git index file in 'index_path', without a repository
 * to back it.
 *
 * Since there is no ODB or working directory behind this index,
 * any Index methods which rely on these (e.g. index_add) will
 * fail with the GIT_EBAREINDEX error code.
 *
 * If you need to access the index of an actual repository,
 * use the `git_repository_index` wrapper.
 *
 * The index must be freed once it's no longer in use.
 *
 * @param out the pointer for the new index
 * @param index_path the path to the index file in disk
 * @return 0 or an error code
 */
int git_index_open(git_index **out_, const(char)* index_path);

/**
 * Create an in-memory index object.
 *
 * This index object cannot be read/written to the filesystem,
 * but may be used to perform in-memory index operations.
 *
 * The index must be freed once it's no longer in use.
 *
 * @param out the pointer for the new index
 * @return 0 or an error code
 */
int git_index_new(git_index **out_);

/**
 * Free an existing index object.
 *
 * @param index an existing index object
 */
void git_index_free(git_index *index);

/**
 * Get the repository this index relates to
 *
 * @param index The index
 * @return A pointer to the repository
 */
git_repository * git_index_owner(const(git_index)* index);

/**
 * Read index capabilities flags.
 *
 * @param index An existing index object
 * @return A combination of GIT_INDEXCAP values
 */
uint git_index_caps(const(git_index)* index);

/**
 * Set index capabilities flags.
 *
 * If you pass `GIT_INDEXCAP_FROM_OWNER` for the caps, then the
 * capabilities will be read from the config of the owner object,
 * looking at `core.ignorecase`, `core.filemode`, `core.symlinks`.
 *
 * @param index An existing index object
 * @param caps A combination of GIT_INDEXCAP values
 * @return 0 on success, -1 on failure
 */
int git_index_set_caps(git_index *index, uint caps);

/**
 * Update the contents of an existing index object in memory
 * by reading from the hard disk.
 *
 * @param index an existing index object
 * @return 0 or an error code
 */
int git_index_read(git_index *index);

/**
 * Write an existing index object from memory back to disk
 * using an atomic file lock.
 *
 * @param index an existing index object
 * @return 0 or an error code
 */
int git_index_write(git_index *index);

/**
 * Read a tree into the index file with stats
 *
 * The current index contents will be replaced by the specified tree.
 *
 * @param index an existing index object
 * @param tree tree to read
 * @return 0 or an error code
 */
int git_index_read_tree(git_index *index, const(git_tree)* tree);

/**
 * Write the index as a tree
 *
 * This method will scan the index and write a representation
 * of its current state back to disk; it recursively creates
 * tree objects for each of the subtrees stored in the index,
 * but only returns the OID of the root tree. This is the OID
 * that can be used e.g. to create a commit.
 *
 * The index instance cannot be bare, and needs to be associated
 * to an existing repository.
 *
 * The index must not contain any file in conflict.
 *
 * @param out Pointer where to store the OID of the written tree
 * @param index Index to write
 * @return 0 on success, GIT_EUNMERGED when the index is not clean
 * or an error code
 */
int git_index_write_tree(git_oid *out_, git_index *index);

/**
 * Write the index as a tree to the given repository
 *
 * This method will do the same as `git_index_write_tree`, but
 * letting the user choose the repository where the tree will
 * be written.
 *
 * The index must not contain any file in conflict.
 *
 * @param out Pointer where to store OID of the the written tree
 * @param index Index to write
 * @param repo Repository where to write the tree
 * @return 0 on success, GIT_EUNMERGED when the index is not clean
 * or an error code
 */
int git_index_write_tree_to(git_oid *out_, git_index *index, git_repository *repo);

/**@}*/

/** @name Raw Index Entry Functions
 *
 * These functions work on index entries, and allow for raw manipulation
 * of the entries.
 */
/**@{*/

/* Index entry manipulation */

/**
 * Get the count of entries currently in the index
 *
 * @param index an existing index object
 * @return integer of count of current entries
 */
size_t git_index_entrycount(const(git_index)* index);

/**
 * Clear the contents (all the entries) of an index object.
 * This clears the index object in memory; changes must be manually
 * written to disk for them to take effect.
 *
 * @param index an existing index object
 */
void git_index_clear(git_index *index);

/**
 * Get a pointer to one of the entries in the index
 *
 * The entry is not modifiable and should not be freed.  Because the
 * `git_index_entry` struct is a publicly defined struct, you should
 * be able to make your own permanent copy of the data if necessary.
 *
 * @param index an existing index object
 * @param n the position of the entry
 * @return a pointer to the entry; NULL if out of bounds
 */
const(git_index_entry)*  git_index_get_byindex(
	git_index *index, size_t n);

/**
 * Get a pointer to one of the entries in the index
 *
 * The entry is not modifiable and should not be freed.  Because the
 * `git_index_entry` struct is a publicly defined struct, you should
 * be able to make your own permanent copy of the data if necessary.
 *
 * @param index an existing index object
 * @param path path to search
 * @param stage stage to search
 * @return a pointer to the entry; NULL if it was not found
 */
const(git_index_entry)*  git_index_get_bypath(
	git_index *index, const(char)* path, int stage);

/**
 * Remove an entry from the index
 *
 * @param index an existing index object
 * @param path path to search
 * @param stage stage to search
 * @return 0 or an error code
 */
int git_index_remove(git_index *index, const(char)* path, int stage);

/**
 * Remove all entries from the index under a given directory
 *
 * @param index an existing index object
 * @param dir container directory path
 * @param stage stage to search
 * @return 0 or an error code
 */
int git_index_remove_directory(
	git_index *index, const(char)* dir, int stage);

/**
 * Add or update an index entry from an in-memory struct
 *
 * If a previous index entry exists that has the same path and stage
 * as the given 'source_entry', it will be replaced.  Otherwise, the
 * 'source_entry' will be added.
 *
 * A full copy (including the 'path' string) of the given
 * 'source_entry' will be inserted on the index.
 *
 * @param index an existing index object
 * @param source_entry new entry object
 * @return 0 or an error code
 */
int git_index_add(git_index *index, const(git_index_entry)* source_entry);

/**
 * Return the stage number from a git index entry
 *
 * This entry is calculated from the entry's flag attribute like this:
 *
 *	(entry->flags & GIT_IDXENTRY_STAGEMASK) >> GIT_IDXENTRY_STAGESHIFT
 *
 * @param entry The entry
 * @returns the stage number
 */
int git_index_entry_stage(const(git_index_entry)* entry);

/**@}*/

/** @name Workdir Index Entry Functions
 *
 * These functions work on index entries specifically in the working
 * directory (ie, stage 0).
 */
/**@{*/

/**
 * Add or update an index entry from a file on disk
 *
 * The file `path` must be relative to the repository's
 * working folder and must be readable.
 *
 * This method will fail in bare index instances.
 *
 * This forces the file to be added to the index, not looking
 * at gitignore rules.  Those rules can be evaluated through
 * the git_status APIs (in status.h) before calling this.
 *
 * If this file currently is the result of a merge conflict, this
 * file will no longer be marked as conflicting.  The data about
 * the conflict will be moved to the "resolve undo" (REUC) section.
 *
 * @param index an existing index object
 * @param path filename to add
 * @return 0 or an error code
 */
int git_index_add_bypath(git_index *index, const(char)* path);

/**
 * Remove an index entry corresponding to a file on disk
 *
 * The file `path` must be relative to the repository's
 * working folder.  It may exist.
 *
 * If this file currently is the result of a merge conflict, this
 * file will no longer be marked as conflicting.  The data about
 * the conflict will be moved to the "resolve undo" (REUC) section.
 *
 * @param index an existing index object
 * @param path filename to remove
 * @return 0 or an error code
 */
int git_index_remove_bypath(git_index *index, const(char)* path);

/**
 * Add or update index entries matching files in the working directory.
 *
 * This method will fail in bare index instances.
 *
 * The `pathspec` is a list of file names or shell glob patterns that will
 * matched against files in the repository's working directory.  Each file
 * that matches will be added to the index (either updating an existing
 * entry or adding a new entry).  You can disable glob expansion and force
 * exact matching with the `GIT_INDEX_ADD_DISABLE_PATHSPEC_MATCH` flag.
 *
 * Files that are ignored will be skipped (unlike `git_index_add_bypath`).
 * If a file is already tracked in the index, then it *will* be updated
 * even if it is ignored.  Pass the `GIT_INDEX_ADD_FORCE` flag to
 * skip the checking of ignore rules.
 *
 * To emulate `git add -A` and generate an error if the pathspec contains
 * the exact path of an ignored file (when not using FORCE), add the
 * `GIT_INDEX_ADD_CHECK_PATHSPEC` flag.  This checks that each entry
 * in the `pathspec` that is an exact match to a filename on disk is
 * either not ignored or already in the index.  If this check fails, the
 * function will return GIT_EINVALIDSPEC.
 *
 * To emulate `git add -A` with the "dry-run" option, just use a callback
 * function that always returns a positive value.  See below for details.
 *
 * If any files are currently the result of a merge conflict, those files
 * will no longer be marked as conflicting.  The data about the conflicts
 * will be moved to the "resolve undo" (REUC) section.
 *
 * If you provide a callback function, it will be invoked on each matching
 * item in the working directory immediately *before* it is added to /
 * updated in the index.  Returning zero will add the item to the index,
 * greater than zero will skip the item, and less than zero will abort the
 * scan and cause GIT_EUSER to be returned.
 *
 * @param index an existing index object
 * @param pathspec array of path patterns
 * @param flags combination of git_index_add_option_t flags
 * @param callback notification callback for each added/updated path (also
 *                 gets index of matching pathspec entry); can be NULL;
 *                 return 0 to add, >0 to skip, <0 to abort scan.
 * @param payload payload passed through to callback function
 * @return 0 or an error code
 */
int git_index_add_all(
	git_index *index,
	const(git_strarray)* pathspec,
	uint flags,
	git_index_matched_path_cb callback,
	void *payload);

/**
 * Remove all matching index entries.
 *
 * If you provide a callback function, it will be invoked on each matching
 * item in the index immediately *before* it is removed.  Return 0 to
 * remove the item, > 0 to skip the item, and < 0 to abort the scan.
 *
 * @param index An existing index object
 * @param pathspec array of path patterns
 * @param callback notification callback for each removed path (also
 *                 gets index of matching pathspec entry); can be NULL;
 *                 return 0 to add, >0 to skip, <0 to abort scan.
 * @param payload payload passed through to callback function
 * @return 0 or an error code
 */
int git_index_remove_all(
	git_index *index,
	const(git_strarray)* pathspec,
	git_index_matched_path_cb callback,
	void *payload);

/**
 * Update all index entries to match the working directory
 *
 * This method will fail in bare index instances.
 *
 * This scans the existing index entries and synchronizes them with the
 * working directory, deleting them if the corresponding working directory
 * file no longer exists otherwise updating the information (including
 * adding the latest version of file to the ODB if needed).
 *
 * If you provide a callback function, it will be invoked on each matching
 * item in the index immediately *before* it is updated (either refreshed
 * or removed depending on working directory state).  Return 0 to proceed
 * with updating the item, > 0 to skip the item, and < 0 to abort the scan.
 *
 * @param index An existing index object
 * @param pathspec array of path patterns
 * @param callback notification callback for each updated path (also
 *                 gets index of matching pathspec entry); can be NULL;
 *                 return 0 to add, >0 to skip, <0 to abort scan.
 * @param payload payload passed through to callback function
 * @return 0 or an error code
 */
int git_index_update_all(
	git_index *index,
	const(git_strarray)* pathspec,
	git_index_matched_path_cb callback,
	void *payload);

/**
 * Find the first position of any entries which point to given
 * path in the Git index.
 *
 * @param at_pos the address to which the position of the index entry is written (optional)
 * @param index an existing index object
 * @param path path to search
 * @return a zero-based position in the index if found;
 * GIT_ENOTFOUND otherwise
 */
int git_index_find(size_t *at_pos, git_index *index, const(char)* path);

/**@}*/

/** @name Conflict Index Entry Functions
 *
 * These functions work on conflict index entries specifically (ie, stages 1-3)
 */
/**@{*/

/**
 * Add or update index entries to represent a conflict
 *
 * The entries are the entries from the tree included in the merge.  Any
 * entry may be null to indicate that that file was not present in the
 * trees during the merge.  For example, ancestor_entry may be NULL to
 * indicate that a file was added in both branches and must be resolved.
 *
 * @param index an existing index object
 * @param ancestor_entry the entry data for the ancestor of the conflict
 * @param our_entry the entry data for our side of the merge conflict
 * @param their_entry the entry data for their side of the merge conflict
 * @return 0 or an error code
 */
int git_index_conflict_add(
	git_index *index,
	const(git_index_entry)* ancestor_entry,
	const(git_index_entry)* our_entry,
	const(git_index_entry)* their_entry);

/**
 * Get the index entries that represent a conflict of a single file.
 *
 * The entries are not modifiable and should not be freed.  Because the
 * `git_index_entry` struct is a publicly defined struct, you should
 * be able to make your own permanent copy of the data if necessary.
 *
 * @param ancestor_out Pointer to store the ancestor entry
 * @param our_out Pointer to store the our entry
 * @param their_out Pointer to store the their entry
 * @param index an existing index object
 * @param path path to search
 */
int git_index_conflict_get(
	const(git_index_entry)** ancestor_out,
	const(git_index_entry)** our_out,
	const(git_index_entry)** their_out,
	git_index *index,
	const(char)* path);

/**
 * Removes the index entries that represent a conflict of a single file.
 *
 * @param index an existing index object
 * @param path to search
 */
int git_index_conflict_remove(git_index *index, const(char)* path);

/**
 * Remove all conflicts in the index (entries with a stage greater than 0.)
 *
 * @param index an existing index object
 */
void git_index_conflict_cleanup(git_index *index);

/**
 * Determine if the index contains entries representing file conflicts.
 *
 * @return 1 if at least one conflict is found, 0 otherwise.
 */
int git_index_has_conflicts(const(git_index)* index);

/**
 * Create an iterator for the conflicts in the index.  You may not modify the
 * index while iterating, the results are undefined.
 *
 * @return 0 or an error code
 */
int git_index_conflict_iterator_new(
	git_index_conflict_iterator **iterator_out,
	git_index *index);

/**
 * Returns the current conflict (ancestor, ours and theirs entry) and
 * advance the iterator internally to the next value.
 *
 * @param ancestor_out Pointer to store the ancestor side of the conflict
 * @param our_out Pointer to store our side of the conflict
 * @param their_out Pointer to store their side of the conflict
 * @return 0 (no error), GIT_ITEROVER (iteration is done) or an error code
 *         (negative value)
 */
int git_index_conflict_next(
	const(git_index_entry)** ancestor_out,
	const(git_index_entry)** our_out,
	const(git_index_entry)** their_out,
	git_index_conflict_iterator *iterator);

/**
 * Frees a `git_index_conflict_iterator`.
 *
 * @param iterator pointer to the iterator
 */
void git_index_conflict_iterator_free(
	git_index_conflict_iterator *iterator);

/**@}*/



//#endif
