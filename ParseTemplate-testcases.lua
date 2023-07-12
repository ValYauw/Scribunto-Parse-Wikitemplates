-- In a MediaWiki module page: import ParseTemplate
local module = require('Module:ParseTemplate')

-- Import ScribuntoUnit for unit tests
local suite = require('Module:ScribuntoUnit'):new()

-- Modular function
-- For testing purposes: Converts the contents of a Lua table into a human-readable string
function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

function suite:testSimple()
	local test_string = "{{a}}{{b}}cd{{e}}"
	local extractedTemplates = module.extractTemplates(test_string)
	
	local expected_template_a = "{{a}}"
	local result_template_a = extractedTemplates["A"][1]["template_contents"]
	local expected_template_b = "{{b}}"
	local result_template_b = extractedTemplates["B"][1]["template_contents"]
	local expected_template_e = "{{e}}"
	local result_template_e = extractedTemplates["E"][1]["template_contents"]
    
    self:assertEquals(expected_template_a, result_template_a)
    self:assertEquals(expected_template_b, result_template_b)
    self:assertEquals(expected_template_e, result_template_e)
    
    local result_template_c = extractedTemplates["C"]
    self:assertEquals(nil, result_template_c)
    
    local expected_results = {
    	["A"] = {
    		[1] = {
				["start_pos"] = 1,
			    ["end_pos"] = 5,
			    ["template_contents"] = "{{a}}",
			    ["template_name"] = "a",
			    ["template_params"] = { }
			}},
		["B"] = {
			[1] = {
			    ["start_pos"] = 6,
			    ["end_pos"] = 10,
			    ["template_contents"] = "{{b}}",
			    ["template_name"] = "b",
			    ["template_params"] = { }
			}},
		["E"] = {
			[1] = {
			    ["start_pos"] = 13,
			    ["end_pos"] = 17,
			    ["template_contents"] = "{{e}}",
			    ["template_name"] = "e",
			    ["template_params"] = { }
			}}
    }
    self:assertDeepEquals(expected_results, extractedTemplates)
    
end

function suite:testSimpleParams()
	local test_string = "{{a|foo|bar}}{{b|name=egg|bacon}}cd{{e}}"
	local extractedTemplates = module.extractTemplates(test_string)
	
	local expected_template_a = "{{a|foo|bar}}"
	local result_template_a = extractedTemplates["A"][1]["template_contents"]
	local expected_template_b = "{{b|name=egg|bacon}}"
	local result_template_b = extractedTemplates["B"][1]["template_contents"]
	local expected_template_e = "{{e}}"
	local result_template_e = extractedTemplates["E"][1]["template_contents"]
    
    self:assertEquals(expected_template_a, result_template_a)
    self:assertEquals(expected_template_b, result_template_b)
    self:assertEquals(expected_template_e, result_template_e)
    
    local expected_template_a_param_1 = "foo"
    local expected_template_a_param_2 = "bar"
    local result_template_a_param_1 = extractedTemplates["A"][1]["template_params"][1]
    local result_template_a_param_2 = extractedTemplates["A"][1]["template_params"][2]
    self:assertEquals(expected_template_a_param_1, result_template_a_param_1)
    self:assertEquals(expected_template_a_param_2, result_template_a_param_2)
    
    local expected_template_b_param_1 = "egg"
    local expected_template_b_param_2 = "bacon"
    local result_template_b_param_1 = extractedTemplates["B"][1]["template_params"]["name"]
    local result_template_b_param_2 = extractedTemplates["B"][1]["template_params"][1]
    self:assertEquals(expected_template_b_param_1, result_template_b_param_1)
    self:assertEquals(expected_template_b_param_2, result_template_b_param_2)
    
    local expected_results = {
		["A"] = {
			[1] = {
				["start_pos"] = 1,
			    ["end_pos"] = 13,
			    ["template_contents"] = "{{a|foo|bar}}",
			    ["template_name"] = "a",
			    ["template_params"] = {
			       [1] = "foo",
			       [2] = "bar"
		    	}
			}},
		["B"] = {
			[1] = {
			    ["start_pos"] = 14,
			    ["end_pos"] = 33,
			    ["template_contents"] = "{{b|name=egg|bacon}}",
			    ["template_name"] = "b",
			    ["template_params"] = {
			       ["name"] = "egg",
			       [1] = "bacon"
			    }
			}},
		["E"] = {
			[1] = {
			    ["start_pos"] = 36,
			    ["end_pos"] = 40,
			    ["template_contents"] = "{{e}}",
			    ["template_name"] = "e",
			    ["template_params"] = {}
			}}
	}
	self:assertDeepEquals(expected_results, extractedTemplates)
    
end

function suite:testNestedTemplates1()
	local test_string = "{{outer|lorem ipsum {{inner|123|456}}|{{inner|3=foo|4=bar}} dolor sit amet}} fluff fluff"
	local extractedTemplates = module.extractTemplates(test_string)
	
	self:assertEquals(1, #extractedTemplates["Outer"])
	self:assertEquals(2, #extractedTemplates["Inner"])
	
	local obj_result_template_outer = extractedTemplates["Outer"][1]
	local obj_result_template_inner1 = extractedTemplates["Inner"][1]
	local obj_result_template_inner2 = extractedTemplates["Inner"][2]
	
	local expected_template_outer = "{{outer|lorem ipsum {{inner|123|456}}|{{inner|3=foo|4=bar}} dolor sit amet}}"
	local result_template_outer = obj_result_template_outer["template_contents"]
	local expected_template_inner1 = "{{inner|3=foo|4=bar}}"
	local result_template_inner1 = obj_result_template_inner1["template_contents"]
	local expected_template_inner2 = "{{inner|123|456}}"
	local result_template_inner2 = obj_result_template_inner2["template_contents"]
    
    self:assertEquals(expected_template_outer, result_template_outer)
    self:assertEquals(expected_template_inner1, result_template_inner1)
    self:assertEquals(expected_template_inner2, result_template_inner2)
    
    local expected_template_outer_param_1 = "lorem ipsum {{inner|123|456}}"
    local expected_template_outer_param_2 = "{{inner|3=foo|4=bar}} dolor sit amet"
    local result_template_outer_param_1 = obj_result_template_outer["template_params"][1]
    local result_template_outer_param_2 = obj_result_template_outer["template_params"][2]
    self:assertEquals(expected_template_outer_param_1, result_template_outer_param_1)
    self:assertEquals(expected_template_outer_param_2, result_template_outer_param_2)
    
    local expected_template_inner1_param_1 = "foo"
    local expected_template_inner1_param_2 = "bar"
    local result_template_inner1_param_1 = obj_result_template_inner1["template_params"][3]
    local result_template_inner1_param_2 = obj_result_template_inner1["template_params"][4]
    self:assertEquals(expected_template_inner1_param_1, result_template_inner1_param_1)
    self:assertEquals(expected_template_inner1_param_2, result_template_inner1_param_2)
    
    local expected_template_inner2_param_1 = "123"
    local expected_template_inner2_param_2 = "456"
    local result_template_inner2_param_1 = obj_result_template_inner2["template_params"][1]
    local result_template_inner2_param_2 = obj_result_template_inner2["template_params"][2]
    self:assertEquals(expected_template_inner2_param_1, result_template_inner2_param_1)
    self:assertEquals(expected_template_inner2_param_2, result_template_inner2_param_2)
    
    local expected_results = {
		["Outer"] = {
			[1] = {
			    ["start_pos"] = 1,
			    ["end_pos"] = 76,
			    ["template_contents"] = "{{outer|lorem ipsum {{inner|123|456}}|{{inner|3=foo|4=bar}} dolor sit amet}}",
			    ["template_name"] = "outer",
			    ["template_params"] = {
			       [1] = "lorem ipsum {{inner|123|456}}",
			       [2] = "{{inner|3=foo|4=bar}} dolor sit amet"
		    	}
			}},
		["Inner"] = {
            [1] = {
			    ["start_pos"] = 39,
			    ["end_pos"] = 59,
			    ["template_contents"] = "{{inner|3=foo|4=bar}}",
			    ["template_name"] = "inner",
			    ["template_params"] = {
			       [3] = "foo",
			       [4] = "bar"
			    }
			},
		    [2] = {
			    ["start_pos"] = 21,
			    ["end_pos"] = 37,
			    ["template_contents"] = "{{inner|123|456}}",
			    ["template_name"] = "inner",
			    ["template_params"] = {
			       [1] = "123",
			       [2] = "456"
			    }
			}
        }
	}
	self:assertDeepEquals(expected_results, extractedTemplates)
    
end

function suite:testNestedTemplates2()
	local test_string = "{{outer|lorem ipsum {{inner|123|456}}|dolor sit amet|foo={{inner|3=foo|4=bar}}}}"
	local extractedTemplates = module.extractTemplates(test_string)
	
	self:assertEquals(1, #extractedTemplates["Outer"])
	self:assertEquals(2, #extractedTemplates["Inner"])
    
    local expected_results = {
		["Outer"] = {
			[1] = {
			    ["start_pos"] = 1,
			    ["end_pos"] = 80,
			    ["template_contents"] = "{{outer|lorem ipsum {{inner|123|456}}|dolor sit amet|foo={{inner|3=foo|4=bar}}}}",
			    ["template_name"] = "outer",
			    ["template_params"] = {
			       [1] = "lorem ipsum {{inner|123|456}}",
			       [2] = "dolor sit amet",
			       ["foo"] = "{{inner|3=foo|4=bar}}"
		    	}
			}},
		["Inner"] = {
            [1] = {
			    ["start_pos"] = 58,
			    ["end_pos"] = 78,
			    ["template_contents"] = "{{inner|3=foo|4=bar}}",
			    ["template_name"] = "inner",
			    ["template_params"] = {
			       [3] = "foo",
			       [4] = "bar"
			    }
			},
		    [2] = {
			    ["start_pos"] = 21,
			    ["end_pos"] = 37,
			    ["template_contents"] = "{{inner|123|456}}",
			    ["template_name"] = "inner",
			    ["template_params"] = {
			       [1] = "123",
			       [2] = "456"
			    }
			}
        }
	}
	self:assertDeepEquals(expected_results, extractedTemplates)
    
end

function suite:testEscapedCharacters()
	local test_string = "{{template|foo=bar|egg{{=}}bacon|red<nowiki>|</nowiki>green}}"
	local extractedTemplates = module.extractTemplates(test_string)
    
    local expected_results = {
		["Template"] = {
			[1] = {
			    ["start_pos"] = 1,
			    ["end_pos"] = 61,
			    ["template_contents"] = "{{template|foo=bar|egg{{=}}bacon|red<nowiki>|</nowiki>green}}",
			    ["template_name"] = "template",
			    ["template_params"] = {
			       [1] = "egg{{=}}bacon",
			       [2] = "red<nowiki>|</nowiki>green",
			       ["foo"] = "bar"
		    	}
			}},
		["="] = {
            [1] = {
			    ["start_pos"] = 23,
			    ["end_pos"] = 27,
			    ["template_contents"] = "{{=}}",
			    ["template_name"] = "=",
			    ["template_params"] = { }
			}}
	}
	self:assertDeepEquals(expected_results, extractedTemplates)
    
end

function suite:testParserFunctions()
	local test_string = "{{DISPLAYTITLE:a title}}{{template|1|2}}lorem ipsum"
	local extractedTemplates = module.extractTemplates(test_string)
    
    local expected_results = {
		["DISPLAYTITLE"] = {
			[1] = {
			    ["start_pos"] = 1,
			    ["end_pos"] = 24,
			    ["template_contents"] = "{{DISPLAYTITLE:a title}}",
			    ["template_name"] = "DISPLAYTITLE",
			    ["template_params"] = { }
			}},
		["Template"] = {
            [1] = {
			    ["start_pos"] = 25,
			    ["end_pos"] = 40,
			    ["template_contents"] = "{{template|1|2}}",
			    ["template_name"] = "template",
			    ["template_params"] = { 
			    	[1] = "1",
			    	[2] = "2"
			    }
			}}
	}
	self:assertDeepEquals(expected_results, extractedTemplates)
    
end

function suite:testSurplusToken1()
	local test_string = "{{a}}{{b|1|2}}}}"
	local extractedTemplates = module.extractTemplates(test_string)
    
    local expected_results = {
		["A"] = {
			[1] = {
			    ["start_pos"] = 1,
			    ["end_pos"] = 5,
			    ["template_contents"] = "{{a}}",
			    ["template_name"] = "a",
			    ["template_params"] = { }
			}},
		["B"] = {
            [1] = {
			    ["start_pos"] = 6,
			    ["end_pos"] = 14,
			    ["template_contents"] = "{{b|1|2}}",
			    ["template_name"] = "b",
			    ["template_params"] = { 
			    	[1] = "1",
			    	[2] = "2"
			    }
			}}
	}
	self:assertDeepEquals(expected_results, extractedTemplates)
    
end

function suite:testSurplusToken2()
	local test_string = "{{a}}{{b|1|2}}{{"
	local extractedTemplates = module.extractTemplates(test_string)
    
    local expected_results = {
		["A"] = {
			[1] = {
			    ["start_pos"] = 1,
			    ["end_pos"] = 5,
			    ["template_contents"] = "{{a}}",
			    ["template_name"] = "a",
			    ["template_params"] = { }
			}},
		["B"] = {
            [1] = {
			    ["start_pos"] = 6,
			    ["end_pos"] = 14,
			    ["template_contents"] = "{{b|1|2}}",
			    ["template_name"] = "b",
			    ["template_params"] = { 
			    	[1] = "1",
			    	[2] = "2"
			    }
			}}
	}
	self:assertDeepEquals(expected_results, extractedTemplates)
    
end

function suite:testSurplusToken3()
	local test_string = "}}{{a}}{{b|1|2}}"
	local extractedTemplates = module.extractTemplates(test_string)
    
    local expected_results = {
		["A"] = {
			[1] = {
			    ["start_pos"] = 3,
			    ["end_pos"] = 7,
			    ["template_contents"] = "{{a}}",
			    ["template_name"] = "a",
			    ["template_params"] = { }
			}},
		["B"] = {
            [1] = {
			    ["start_pos"] = 8,
			    ["end_pos"] = 16,
			    ["template_contents"] = "{{b|1|2}}",
			    ["template_name"] = "b",
			    ["template_params"] = { 
			    	[1] = "1",
			    	[2] = "2"
			    }
			}}
	}
	self:assertDeepEquals(expected_results, extractedTemplates)
    
end

function suite:testUltraNestedTemplates()
	local test_string = "{{super|{{outer|a|{{inner|1|2}}|b}}|{{inner|3=foo|4=bar}}}}"
	local extractedTemplates = module.extractTemplates(test_string)
	
	self:assertEquals(1, #extractedTemplates["Super"], "Expected number of extracted Super templates to be 1")
	self:assertEquals(1, #extractedTemplates["Outer"], "Expected number of extracted Outer templates to be 1")
	self:assertEquals(2, #extractedTemplates["Inner"], "Expected number of extracted Inner templates to be 2")
	
	local obj_result_template_super = extractedTemplates["Super"][1]
	local obj_result_template_outer = extractedTemplates["Outer"][1]
	local obj_result_template_inner1 = extractedTemplates["Inner"][1]
	local obj_result_template_inner2 = extractedTemplates["Inner"][2]
	
	local expected_template_super = "{{super|{{outer|a|{{inner|1|2}}|b}}|{{inner|3=foo|4=bar}}}}"
	local result_template_super = obj_result_template_super["template_contents"]
	local expected_template_outer = "{{outer|a|{{inner|1|2}}|b}}"
	local result_template_outer = obj_result_template_outer["template_contents"]
	local expected_template_inner1 = "{{inner|3=foo|4=bar}}"
	local result_template_inner1 = obj_result_template_inner1["template_contents"]
	local expected_template_inner2 = "{{inner|1|2}}"
	local result_template_inner2 = obj_result_template_inner2["template_contents"]
    
    self:assertEquals(expected_template_outer, result_template_outer)
    self:assertEquals(expected_template_inner1, result_template_inner1)
    self:assertEquals(expected_template_inner2, result_template_inner2)
    
    local expected_results = {
		["Super"] = {
			[1] = {
			    ["start_pos"] = 1,
			    ["end_pos"] = 59,
			    ["template_contents"] = "{{super|{{outer|a|{{inner|1|2}}|b}}|{{inner|3=foo|4=bar}}}}",
			    ["template_name"] = "super",
			    ["template_params"] = {
			       [1] = "{{outer|a|{{inner|1|2}}|b}}",
			       [2] = "{{inner|3=foo|4=bar}}"
		    	}
			}},
		["Outer"] = {
             [1] = {
			    ["start_pos"] = 9,
			    ["end_pos"] = 35,
			    ["template_contents"] = "{{outer|a|{{inner|1|2}}|b}}",
			    ["template_name"] = "outer",
			    ["template_params"] = {
			       [1] = "a",
			       [2] = "{{inner|1|2}}",
                   [3] = "b"
			    }
			}},
		["Inner"] = {
            [1] = {
			    ["start_pos"] = 37,
			    ["end_pos"] = 57,
			    ["template_contents"] = "{{inner|3=foo|4=bar}}",
			    ["template_name"] = "inner",
			    ["template_params"] = {
			       [3] = "foo",
			       [4] = "bar"
			    }
			},
			[2] = {
			    ["start_pos"] = 19,
			    ["end_pos"] = 31,
			    ["template_contents"] = "{{inner|1|2}}",
			    ["template_name"] = "inner",
			    ["template_params"] = {
			       [1] = "1",
			       [2] = "2"
			    }
			}}
		}
	self:assertDeepEquals(expected_results, extractedTemplates)
    
end

return suite