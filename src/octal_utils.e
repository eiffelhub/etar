note
	description: "[
		Utilities to print numbers in octal representation 
		and parse octal formatted strings
		
		Inherit from this class to use its facilities
		
		Parsing allows natural numbers only
	]"
	author: ""
	date: "$Date$"
	revision: "$Revision$"

class
	OCTAL_UTILS

feature {NONE} -- Parsing

	octal_string_to_natural_16 (a_string: STRING_8): NATURAL_32
			-- Converts `a_string' (interpreted as octal) to a NATURAL_16
		require
			valid_format: a_string.is_natural_16 and not a_string.has ('8') and not a_string.has ('9')
			in_range: (leading_zeros_count (a_string) < octal_16_max_digits) or
						((leading_zeros_count (a_string) = octal_16_max_digits) and (a_string[octal_16_max_digits].code <= ('1').code))
		do
			Result := octal_string_to_natural_64 (a_string).to_natural_16
		end

	octal_string_to_natural_32 (a_string: STRING_8): NATURAL_32
			-- Converts `a_string' (interpreted as octal) to a NATURAL_32
		require
			valid_format: a_string.is_natural_32 and not a_string.has ('8') and not a_string.has ('9')
			in_range: (leading_zeros_count (a_string) < octal_32_max_digits) or
						((leading_zeros_count (a_string) = octal_32_max_digits) and (a_string[octal_32_max_digits].code <= ('3').code))
		do
			Result := octal_string_to_natural_64 (a_string).to_natural_32
		end

	octal_string_to_natural_64 (a_string: STRING_8): NATURAL_64
			-- Converts `a_string' (interpreted as octal) to a NATURAL_64
		require
			valid_format: a_string.is_natural_64 and not a_string.has ('8') and not a_string.has ('9')
			in_range: (leading_zeros_count (a_string) < octal_64_max_digits) or
						((leading_zeros_count (a_string) = octal_64_max_digits) and (a_string[octal_64_max_digits].code <= ('1').code))
		local
			digit_weight: NATURAL_64
			i: INTEGER
			leading_zeros: INTEGER
		do
			digit_weight := 1
			Result := 0
			from
				i := a_string.count
				leading_zeros := leading_zeros_count (a_string)
			until
				i < leading_zeros + 1 -- last non-zero digit
			loop
				Result := Result + digit_weight * (a_string[i].code - ('0').code).to_natural_64
				digit_weight := digit_weight * 8
				i := i - 1
			end
		end

feature {NONE} -- Output

	natural_16_to_octal_string (n: NATURAL_16): STRING_8
			-- Converts `n' to an octal string
		do
			Result := natural_64_to_octal_string (n.to_natural_64)
		end

	natural_32_to_octal_string (n: NATURAL_32): STRING_8
			-- Converts `n' to an octal string
		do
			Result := natural_64_to_octal_string (n.to_natural_64)
		end

	natural_64_to_octal_string (n: NATURAL_64): STRING_8
			-- Converts `n' to an octal string
		local
			tmp: NATURAL_64
		do
			from
				tmp := n
				create Result.make (octal_64_max_digits)
			until
				tmp = 0
			loop
				Result.append_character (natural_8_to_octal_character ((tmp & 0c7).to_natural_8))
				tmp := tmp |>> 3
			end
		end

feature {NONE} -- Utilities

	natural_8_to_octal_character (n: NATURAL_8): CHARACTER_8
			-- Convert `n' to its corresponding character representation
		require
			in_range: 0 <= n and n <= 7
		do
			Result := (('0').code + n.to_integer_32).to_character_8
		ensure
			valid_character: ("01234567").has (Result)
		end

	leading_zeros_count (a_string: STRING_8): INTEGER
			-- The number of leading zeros of `a_string'
		do
			from
				Result := 1
			until
				Result >= a_string.count or else a_string[Result] /= '0'
			loop
				Result := Result + 1
			end
			-- Loop stops at first non-zero digit, hence subtract one
			Result := Result - 1
		end

	truncate_leading_zeros (a_string: STRING_8)
			-- Truncates leading zeros of `a_string' until it has no more leading zeros or only one character left
		do
			a_string.keep_tail (a_string.count - leading_zeros_count(a_string))
		end

	pad (a_string: STRING_8; n: INTEGER)
			-- Pad `a_string' with `n' zeros
		require
			positive: n >= 0
		local
			zeros: STRING_8
		do
			create zeros.make_filled ('0', n)
			a_string.prepend_string (zeros)
		ensure
			prepended: a_string.count + n = old a_string.count -- Hope old makes a copy
			zeros_prepended: a_string.head (n).to_natural_64 = 0
		end

feature {NONE} -- Constants

	octal_16_max_digits: INTEGER = 6
			-- Maximal digits of a 16 bit natural octal string representation

	octal_32_max_digits: INTEGER = 11
			-- Maximal digits of a 32 bit natural octal string representation

	octal_64_max_digits: INTEGER = 22
			-- Maximal digits of a 64 bit natural octal string representation

end
