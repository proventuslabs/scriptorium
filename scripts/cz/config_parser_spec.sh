# shellcheck shell=bash

Describe 'parse_config'
	Include ./config_parser.sh

	It 'should ignore empty stdin'
		When call parse_config
		The status should be success
		The output should equal ""
	End

	It 'should ignore comments'
		Data
			#|# comment
			#|   # another comment
		End
		When call parse_config
		The status should be success
		The output should equal ""
	End

	It 'should ignore empty lines'
		Data
			#|
			#|
		End
		When call parse_config
		The status should be success
		The output should equal ""
	End

	It 'should parse global scopes'
		Data
			#|*||main,common
		End
		When call parse_config
		The status should be success
		The variable GLOBAL_SCOPES[0] should equal "main"
		The variable GLOBAL_SCOPES[1] should equal "common"
	End

	It 'should parse type definitions'
		Data
			#|feat|A new feature|api
		End
		When call parse_config
		The status should be success
		The variable TYPES[0] should equal "feat"
		The variable DESCRIPTIONS[0] should equal "A new feature"
		The variable SCOPES[0] should equal "api"
	End

	It 'should inherit global scopes'
		Data
			#|*||main,common
			#|feat|A new feature|api
		End
		When call parse_config
		The status should be success
		The variable SCOPES[0] should equal "main common api"
	End

	It 'should remove scopes with - prefix'
		Data
			#|*||main,common
			#|feat|A new feature|-main
		End
		When call parse_config
		The status should be success
		The variable SCOPES[0] should equal "common"
	End

	It 'should add and remove scopes together'
		Data
			#|*||main,common
			#|feat|A new feature|api,ui,-main
		End
		When call parse_config
		The status should be success
		The variable SCOPES[0] should equal "common api ui"
	End

	It 'should handle explicit + prefix'
		Data
			#|*||main
			#|feat|A new feature|+api,+ui
		End
		When call parse_config
		The status should be success
		The variable SCOPES[0] should equal "main api ui"
	End

	It 'should handle last definition wins'
		Data
			#|feat|First|api
			#|feat|Second|ui
		End
		When call parse_config
		The status should be success
		The variable TYPES[0] should equal "feat"
		The variable DESCRIPTIONS[0] should equal "Second"
		The variable SCOPES[0] should equal "ui"
	End

End
