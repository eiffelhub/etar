note
	description: "[
		Eiffel tests that can be executed by testing tool.
	]"
	author: "EiffelStudio test wizard"
	date: "$Date$"
	revision: "$Revision$"
	testing: "type/manual"

class
	FILE_UNARCHIVER_TEST_SET

inherit
	EQA_TEST_SET

feature -- Test routines

	test_easy_file_unarchiver
		local
			unit_under_test: FILE_UNARCHIVER
			p: MANAGED_POINTER
		do
			create unit_under_test
			create p.make (easy_header_payload_blob.count)
			p.put_special_character_8 (easy_header_payload_blob, 0, 0, easy_header_payload_blob.count)

			assert ("Correct payload size", p.count = {TAR_CONST}.tar_block_size)

			assert ("Can unarchive regular file", unit_under_test.can_unarchive (easy_header))

			unit_under_test.initialize (easy_header)

			assert ("Not finished", not unit_under_test.unarchiving_finished)
			assert ("No blocks processed", unit_under_test.unarchived_blocks = 0)

			unit_under_test.unarchive_block (p, 0)

			assert ("Finished", unit_under_test.unarchiving_finished)
			assert ("One block unarchived", unit_under_test.unarchived_blocks = 1)

			-- TODO: Compare file contents and metadata
		end

feature {NONE} -- Data - easy

	easy_header: TAR_HEADER
			-- Header for the easy test data
		once
			create Result.make
			Result.set_filename (create {PATH}.make_from_string ("test_files/unarchiver_easy.txt"))
			Result.set_mode (0c0644)
			Result.set_user_id (0c1750)
			Result.set_group_id (0c144)
			Result.set_size (0c60)
			Result.set_mtime (0c12636054745) -- ~ Dec 21 20:58
			Result.set_typeflag ({TAR_CONST}.tar_typeflag_regular_file)
			Result.set_user_name ("nicolas")
			Result.set_group_name ("users")
		end

	easy_header_payload_blob: SPECIAL[CHARACTER_8]
			-- Payload blob for easy test data
		local
			header_template: STRING_8
		once
			header_template := "# ETAR^Eiffel compression library based on tar.^$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$"
			header_template.replace_substring_all ("$", "%U")
			header_template.replace_substring_all ("^", "%N")
			Result := header_template.area
			Result.remove_tail (1)
		end
end


