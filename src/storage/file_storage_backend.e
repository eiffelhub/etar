note
	description: "[
		Storage backends for files
	]"
	author: ""
	date: "$Date$"
	revision: "$Revision$"

class
	FILE_STORAGE_BACKEND

inherit
	STORAGE_BACKEND
		redefine
			default_create
		end

create
	make_from_file,
	make_from_filename

feature {NONE} -- Initialization

	default_create
			-- Used to initialize internal status
		do
			create block_buffer.make ({TAR_CONST}.tar_block_size)
			create {ARRAYED_CIRCULAR [MANAGED_POINTER]} buffer.make (2)

			Precursor
		end

	make_from_file (a_file: FILE)
			-- Create new instance for `a_file'
			-- Will create a clone of `a_file' to prevent interference with client-side changes
		do
			create {RAW_FILE} backend.make_with_path (a_file.path)
			default_create
		ensure
			backend_closed: backend.is_closed
		end

	make_from_filename (a_filename: READABLE_STRING_GENERAL)
			-- Create new instance for `a_filename'
		do
			create {RAW_FILE} backend.make_with_name (a_filename)
			default_create
		ensure
			backend_closed: backend.is_closed
		end

feature -- Status setting

	open_read
			-- Open for reading
		do
			if not has_error then
				if backend.exists and then backend.is_readable then
					backend.open_read
				elseif not backend.exists then
					report_error ("File does not exist")
				elseif not backend.is_readable then
					report_error ("File is not readable")
				else
					report_error ("Unknown error")
				end
			end
		end

	open_write
			-- Open for writing
		do
			if not has_error then
				if backend.exists implies backend.is_writable then
					backend.open_write
				elseif backend.exists then
					report_error ("File is not writable")
				else
					report_error ("Unknown error")
				end
			end
		end

	close
			-- Close backend
		do
			if not has_error then
				backend.flush
				backend.close
			end
		end

feature -- Status

	archive_finished: BOOLEAN
			-- Indicates whether the next two blocks only contain NUL bytes or the file has not enough characters to read
		do
			Result := backend.is_closed
			if not Result then
				from

				until
					buffer.count >= 2 or has_error
				loop
					read_block_to_buffer
				end
			end

			Result := has_error or else (only_nul_bytes (buffer.at (1)) and only_nul_bytes (buffer.at (2)))

		end

	block_ready: BOOLEAN
			-- Indicate whether there is a block ready
		do
			Result := not has_error and then has_valid_block
		end

	is_readable: BOOLEAN
			-- Indicates whether this instance can be read from
		do
			Result := not has_error and then backend.is_open_read
		end

	is_writable: BOOLEAN
			-- Indicates whether this instance can be written to
		do
			Result := not has_error and then backend.is_open_write
		end

	is_closed: BOOLEAN
			-- Indicates whether backend is closed
		do
			Result := backend.is_closed
		end

feature -- Reading

	last_block: MANAGED_POINTER
			-- Return last block that was read
		do
			Result := block_buffer
		end

	read_block
			-- Read next block
		do
			if not buffer.is_empty then
					-- There are buffered items, use them
				block_buffer := buffer.item
				buffer.remove

				has_valid_block := True
			else
				backend.read_to_managed_pointer (block_buffer, 0, block_buffer.count)
				has_valid_block := backend.bytes_read = block_buffer.count

				if not has_valid_block then
					close
					report_error ("Not enough bytes to read full block")
				end
			end
		end

feature -- Writing

	write_block (a_block: MANAGED_POINTER)
			-- Write `a_block'
		do
			backend.put_managed_pointer (a_block, 0, a_block.count)
		end

	finalize
			-- Finalize archive (write two 0 blocks)
		local
			l_block: MANAGED_POINTER
			l_template: STRING_8
		do
			l_template := "%U"
			l_template.multiply ({TAR_CONST}.tar_block_size)
			create l_block.make_from_pointer (l_template.area.base_address, {TAR_CONST}.tar_block_size)
			write_block (l_block)
			write_block (l_block)
			backend.flush
			close
		end

feature {NONE} -- Implementation

	backend: FILE
			-- file backend

	buffer: DYNAMIC_CIRCULAR [MANAGED_POINTER]
			-- buffers blocks that were read ahead

	block_buffer: MANAGED_POINTER
			-- buffer to use for next read operation

	has_valid_block: BOOLEAN
			-- Boolean flag for `block_ready'

	read_block_to_buffer
			-- Read block and add it to the buffer
		local
			l_buffer: MANAGED_POINTER
		do
			create l_buffer.make (block_buffer.count)
			backend.read_to_managed_pointer (l_buffer, 0, l_buffer.count)

			if backend.bytes_read = l_buffer.count then
				buffer.force (l_buffer)
			else
				close
				report_error ("Not enough bytes to read full block")
			end
		ensure
			error_or_one_more_entry: has_error or else buffer.count = old buffer.count + 1
		end

	only_nul_bytes (a_block: MANAGED_POINTER): BOOLEAN
			-- Check whether `a_block' only consists of NUL bytes
		do
			Result := a_block.read_special_character_8 (0, a_block.count).for_all_in_bounds (
				agent (c: CHARACTER_8): BOOLEAN
					do
						Result := c = '%U'
					end, 0, a_block.count - 1)
		end

invariant
	buffer_size: block_buffer.count = {TAR_CONST}.tar_block_size
	buffer_entries_size: across buffer as l_cursor all l_cursor.item.count = {TAR_CONST}.tar_block_size end
end