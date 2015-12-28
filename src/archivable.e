note
	description: "[
		Common ancestor for all ARCHIVABLES
	]"
	author: ""
	date: "$Date$"
	revision: "$Revision$"

deferred class
	ARCHIVABLE

feature -- Status

	finished_writing: BOOLEAN
			-- Indicates whether everything is written (usefull when using blockwise writing)
		do
			Result := written_blocks = required_blocks
		end

	required_blocks: INTEGER
			-- Indicates how much space this archivable requires in blocks
		deferred
		ensure
			non_negative: Result >= 0
		end

	written_blocks: INTEGER
			-- Indicates how many payload blocks have been written so far

	header: TAR_HEADER
			-- Header that belongs to the payload
		deferred
		end


feature -- Output

	write_block_to_managed_pointer (p: MANAGED_POINTER; pos: INTEGER)
			-- Write next block to `p' starting from `pos'
		require
			non_negative_position: pos >= 0
			enough_space: p.count >= pos + {TAR_CONST}.tar_block_size
			not_finished: not finished_writing
		deferred
		ensure
			block_written: written_blocks = old written_blocks + 1
		end

	write_block_to_new_managed_pointer: MANAGED_POINTER
			-- Write next block to a new managed pointer
		do
			create Result.make ({TAR_CONST}.tar_block_size)
			write_block_to_managed_pointer (Result, 0)
		ensure
			block_written: written_blocks = old written_blocks + 1
			block_size: Result.count = {TAR_CONST}.tar_block_size
		end

	write_to_managed_pointer (p: MANAGED_POINTER; pos: INTEGER)
			-- Write the whole object to `p' (starting from `pos')
			-- This will not change the position used for block based writing
			-- keep in mind that this might use quite a lot of memory for large objects
		require
			non_negative_position: pos >= 0
			enough_space: p.count >= pos + required_blocks * {TAR_CONST}.tar_block_size
		deferred
		end

	write_to_new_managed_pointer: MANAGED_POINTER
			-- Write the whole object to a new managed pointer
			-- This will not change the position used for block based writing
			-- keep in mind that this might use quite a lot of memory for large objects
		do
			create Result.make (required_blocks * {TAR_CONST}.tar_block_size)
			write_to_managed_pointer (Result, 0)
		end

feature {NONE} -- Utilites

	needed_blocks (n: INTEGER): INTEGER
			-- Indicate how many blocks are needed to represent `n' bytes
		require
			non_negative_bytes: n >= 0
		do
			Result := (n + {TAR_CONST}.tar_block_size - 1) // {TAR_CONST}.tar_block_size
		ensure
			bytes_fit: n <= Result * {TAR_CONST}.tar_block_size
			smallest_fit: (Result - 1) * {TAR_CONST}.tar_block_size < n
		end

	pad (p: MANAGED_POINTER; pos: INTEGER; n: INTEGER)
			-- pad `p' with `n' NUL-bytes starting at `pos'
		require
			non_negative_position: pos >= 0
			non_negative_length: n >= 0
			enough_space: p.count >= pos + n
		local
			l_padding: SPECIAL[CHARACTER_8]
		do
			if n > 0 then
				create l_padding.make_filled ('%U', n)
				p.put_special_character_8 (l_padding, 0, pos, n)
			end
		end

invariant
	non_negative_written_blocks: written_blocks >= 0

end
