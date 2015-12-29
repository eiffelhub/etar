note
	description: "[
		UNARCHIVER for pax payload
	]"
	author: ""
	date: "$Date$"
	revision: "$Revision$"

class
	PAX_UNARCHIVER

inherit
	UNARCHIVER
	redefine
		default_create
	end

feature -- Initialization

	default_create
			-- Initialize unarchiver
		do
			Precursor

				-- Initialize internals. Capacities chosen from gnutar's default pax entries
			create entries.make_equal (3)	-- pax provides atime, mtime and ctime

			create active_length.make (10)	-- sufficient for nearly all length values
			create active_key.make (10)		-- sufficient for all pax defined keys
			create active_value.make_empty	-- grows on demand after key is parsed

			initialize_error
		end

feature -- Status

	can_unarchive (a_header: TAR_HEADER): BOOLEAN
			-- Indicate whether this type of unarchiver can unarchive payload with
			-- header `a_header'
		do
			Result := a_header.typeflag = {TAR_CONST}.tar_typeflag_pax_extended or
						a_header.typeflag = {TAR_CONST}.tar_typeflag_pax_global
		ensure then
			correct_result: Result = (a_header.typeflag = {TAR_CONST}.tar_typeflag_pax_extended or
											a_header.typeflag = {TAR_CONST}.tar_typeflag_pax_global)
		end

	get_value (a_key: STRING_8): detachable READABLE_STRING_8
			-- Get value corresponding to `a_key'
			-- Returns void if there is none
		do
			Result := entries.item (a_key)
		end

feature -- Access: error

	has_error: BOOLEAN
			-- Error occurred?
		do
			Result := not error_messages.is_empty
		end

	error_messages: LIST [READABLE_STRING_32]
			-- Error messages.		

feature {NONE} -- Error: Internal only

	report_error (a_message: READABLE_STRING_GENERAL)
			-- Report error message `a_message'.
		do
			error_messages.force (a_message.as_string_32)
		ensure
			has_error: has_error
		end

	reset_error
			-- Reset errors.
		do
			error_messages.wipe_out
		ensure
			has_no_error: not has_error
		end

	initialize_error
			-- Initialize error handling structures
		do
			create {ARRAYED_LIST [READABLE_STRING_32]} error_messages.make (1)
		end

feature -- Unarchiving

	unarchive_block (p: MANAGED_POINTER; a_pos: INTEGER)
			-- Unarchive next block, stored in `p' starting at `a_pos'
			-- the payload has the form
			-- length key=value%N
		local
			i: INTEGER
			c: CHARACTER_8
		do
			if attached active_header as l_header then
				from
					i := 0
				until
					i >= {TAR_CONST}.tar_block_size or
					i.as_natural_64 >= l_header.size - (unarchived_blocks * {TAR_CONST}.tar_block_size).as_natural_64 or
					has_error
				loop
					c := p.read_character (a_pos + i)

					inspect parsing_state
					when ps_length then
						handle_length_character (c)
					when ps_key then
						handle_key_character (c)
					when ps_value then
						handle_value_character (c)
					else
						-- Unreachable (invariant)
					end

					i := i + 1
				end
			else
				-- Unreachable (precondition)
			end
			unarchived_blocks := unarchived_blocks + 1

			if unarchiving_finished then
				if parsing_state /= ps_length then
					report_error ("Parsing not finished, current key: " + active_key)
				end
			end
		end

feature {NONE} -- Implementation

	do_internal_initialization
			-- Initialize subclass specific internals after initialize has done its job
		do
			entries.wipe_out
			reset_error
			reset_parser
		end

	entries: HASH_TABLE [STRING_8, STRING_8]
			-- The entries in the current payload

feature {NONE} -- parsing finite state machine

	active_length: STRING_8
			-- Length field entry for which parsing is in progress

	active_key: STRING_8
			-- Key field entry for which parsing is in progress

	active_value: STRING_8
			-- Value field entry for which parsing is in progress

	parsing_state: INTEGER
			-- In what parsing state are we currently? One of the following constants

	ps_length: INTEGER = 0
			-- parsing state: next block to be parsed belongs to pax header

	ps_key: INTEGER = 1
			-- parsing state: next block to be parsed belongs to pax payload

	ps_value: INTEGER = 2
			-- parsing state: next block to be parsed belongs to ustar header

	handle_length_character (c: CHARACTER_8)
			-- Handle `c', treating it as a length character
		require
			no_errors: not has_error
			correct_state: parsing_state = ps_length
		do
			inspect c
			when ' ' then
				if not active_length.is_empty then
					parsing_state := ps_key
				else
					report_error ("No length parsed, first character was space")
				end
			when '=' then
				report_error ("No key found - instead found equals sign, currently parsed length: " + active_length)
			when '%N' then
				report_error ("No key found - instead found newline character, currently parsed length: " + active_length)
			else
				if c.is_digit then
					active_length.append_character (c)
				else
					report_error ("Detected non-digit character in payload entry")
				end
			end
		end

	handle_key_character (c: CHARACTER_8)
			-- Handle `c', treating it as a key character
		require
			no_errors: not has_error
			correct_state: parsing_state = ps_key
		do
			inspect c
			when '=' then
				if not active_key.is_empty then
					parsing_state := ps_value
				else
					report_error ("No key found, currently parsed length: " + active_length)
				end
			when '%N' then
				report_error ("No value found - instead found newline character, currently parsed key: " + active_key)
			else
				active_key.append_character (c)
			end
		end

	handle_value_character (c: CHARACTER_8)
			-- Handle `c', treating it as a value character
		require
			no_errors: not has_error
			correct_state: parsing_state = ps_value
		do
			inspect c
			when '%N' then
				if active_length.count + active_key.count + active_value.count + 3 = active_length.to_integer then
					entries.force (active_value.twin, active_key.twin)
					reset_parser
				else
					report_error ("Entry was finished before/after indicated length. Key: " + active_key)
				end
			else
				active_value.append_character (c)
			end
		end

	reset_parser
			-- Reset parser state to process a new entry
		require
			no_errors: not has_error
		do
			parsing_state := ps_length
			active_length.wipe_out
			active_key.wipe_out
			active_value.wipe_out
		end

invariant
	use_object_comparison: entries.object_comparison
	active_length_is_natural: active_length.is_empty or active_length.is_natural
	active_key_has_no_equal_sign: not active_key.has ('=')
	no_newline_parsing: not active_length.has ('%N') and not active_key.has ('%N') and not active_value.has ('%N')
	length_state_active_fields: parsing_state = ps_length implies (active_key.is_empty and active_value.is_empty)
	key_state_active_fields: parsing_state = ps_key implies (not active_length.is_empty and active_value.is_empty)
	value_state_active_fields: parsing_state = ps_value implies (not active_length.is_empty and not active_key.is_empty)
	correct_state: parsing_state = ps_length or parsing_state = ps_key or parsing_state = ps_value

end
