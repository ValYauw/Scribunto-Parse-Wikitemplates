local p = {}

-- Unicode String Library
local match = mw.ustring.match
local gmatch = mw.ustring.gmatch
local find = mw.ustring.find
local len = mw.ustring.len
local replace = mw.ustring.gsub
local sub = mw.ustring.sub
local split = mw.text.split
local lower = mw.ustring.lower
local upper = mw.ustring.upper
local trim = mw.text.trim

------------------------------------------------------------------------
-- Auxiliary function
-- Displays the contents of a Lua table into a human-readable format
-- @param o 		Lua table
-- returns			string
------------------------------------------------------------------------
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

------------------------------------------------------------------------
-- Auxiliary function
-- Slices a section of a Lua table
-- @param t 		Lua table
-- @param index 	start index of slice
-- @param length	max. number of elements in sliced table
-- returns			Lua table
------------------------------------------------------------------------
-- Example Usage:	slice( { 1, 2, 3, 4 }, 2, 2 )	-> { 2, 3 }
--					slice( { 1, 2, 3, 4 }, 2, 4 )	-> { 2, 3, 4 }
--					slice( { 1, 2, 3, 4 }, 5, 2 )	-> { }
------------------------------------------------------------------------
function slice(t, index, length)
	local new_table = { }
	local termination = index + length 
	if termination > #t then termination = #t + 1 end
	while (index < termination) do
		table.insert(new_table, t[index])
		index = index + 1
	end
	return new_table
end

------------------------------------------------------------------------
-- Auxiliary function
-- Outputs an array-like Lua table containing the start or ending positions of
-- token characters found matched within a string
-- @param str 			String to search token characters in
-- @param tokenPattern	Lua pattern representing the token character(s) to look for
-- @param getEndPos		Boolean. Set true to get the function to output array of ending positions.
--						Array of starting positions is output by default.
-- @param offsetOne		Boolean. Offset one character to the right/left when extracting starting/ending positions.
--						To emulate lookahead/lookbehind in regex
-- returns				Lua table
------------------------------------------------------------------------
-- Example Usage:	getTokenPositions("{{template|{{foo}}|bar}}", "{{") ->  { 1, 12 }
--					getTokenPositions("{{template|{{foo}}|bar}}", "}}", true) ->  { 18, 24 }
------------------------------------------------------------------------
function getTokenPositions(str, tokenPattern, getEndPos, offsetOne)
	getEndPos = getEndPos or false
	offsetOne = offsetOne or false
	local arr = { }
	local lastTokenPosition = 1
	local startPos, endPos = find(str, tokenPattern, lastTokenPosition)
	while startPos ~= nil do
		if offsetOne then 
			startPos = startPos + 1
			endPos = endPos - 1
		end
		if getEndPos then table.insert(arr, endPos)
		else table.insert(arr, startPos) end
		lastTokenPosition = endPos + 1
		startPos, endPos = find(str, tokenPattern, lastTokenPosition)
	end
	return arr
end

------------------------------------------------------------------------
-- Sub-level function
-- Parse wikitext and extract the templates (e.g. {{TEMPLATE}}) and parser functions 
--	(e.g. {{DEFAULTSORT:}}) in the page 
-- Should be able to get nesting and nested templates
--
-- @param strWikitext 			Wikitext contents of a page
-- returns						Array-like Lua table containing:
--									Object-like Lua table with keys "start_pos" and "end_pos"
------------------------------------------------------------------------
function parseTemplates(strWikitext)
    
    local charIdx = 1
	local prevChar = nil
	local numOpeningTokens = 0
	local numClosingTokens = 0
	local tblTemplateTokens = { }
	local idxTblTemplateTokens = 0
	local tblIdxTemplateOpenTokens = { }
	local skipNextChar = true
	
	for curChar in mw.ustring.gcodepoint(strWikitext) do
      --mw.log(prevChar, curChar)
      curChar = mw.ustring.char(curChar)
      
	  if skipNextChar then
	  	skipNextChar = false
	  else
	  
	      -- Template opening token
		  if prevChar == "{" and curChar == "{" then
		    numOpeningTokens = numOpeningTokens + 1
		    if numOpeningTokens == 1 then
		      isEnclosedInOutermostTemplate = true
		      idxTblTemplateTokens = idxTblTemplateTokens + 1
		    end
		    table.insert(tblTemplateTokens, { ["start_pos"] = charIdx-1 })
		    table.insert(tblIdxTemplateOpenTokens, 1, #tblTemplateTokens)
		    skipNextChar = true
		    --mw.log("Encountered open token ", charIdx, numOpeningTokens, numClosingTokens)
		  end
		  
		  -- Template closing token
		  if numOpeningTokens > 0 and prevChar == "}" and curChar == "}" then
		    numClosingTokens = numClosingTokens + 1
		    tblTemplateTokens[tblIdxTemplateOpenTokens[1]]["end_pos"] = charIdx
		    table.remove(tblIdxTemplateOpenTokens, 1)
		    skipNextChar = true
		    --mw.log("Encountered closing token ", charIdx, numOpeningTokens, numClosingTokens)
		  end
		
		  -- Reset counters
		  if numOpeningTokens == numClosingTokens and numOpeningTokens > 0 then
		  	idxTblTemplateTokens = idxTblTemplateTokens + numOpeningTokens + 1
		    numOpeningTokens = 0
		    numClosingTokens = 0
		    --mw.log("Reset opening & closing tokens")
		  end
		  
	  end
	
	  charIdx = charIdx + 1
	  prevChar = curChar

	end
	
	return tblTemplateTokens

end

------------------------------------------------------------------------
-- Auxiliary function
-- For a given portion of wikitext, get imposed limits as defined by an opening token and a closing token within the wikitext string
-- e.g. get limits where a template may be nested within the given strTemplate, wherein
--      the opening token is '{{' and the closing token is '}}'
--      thus parameters of the outer template should not be parsed between these limits
--
-- @param strTemplate 			String containing wikitext, declaring a template
-- @param openTokenPattern		Lua pattern for opening token
-- @param closeTokenPattern		Lua pattern for closing token
-- @param offsetOne				Boolean. Offset one character to the right/left when extracting starting/ending positions.
--								To emulate lookahead/lookbehind in regex
-- returns						Array-like Lua table of Lua tables containing two elements (start of limit & end of limit) 
------------------------------------------------------------------------
function getInvalidPositionLimits(strTemplate, openTokenPattern, closeTokenPattern, offsetOne)
	
	local openTokenPos = getTokenPositions(strTemplate, openTokenPattern, false, offsetOne)
	local closeTokenPos = getTokenPositions(strTemplate, closeTokenPattern, true, offsetOne)
	
	local numTokens = #openTokenPos
	if numTokens == 0 then return { } end
	if numTokens == 1 and closeTokenPos[1] ~= nil then return { [1] = { [1]=openTokenPos[1], [2]=closeTokenPos[1] } } end
	
	local arr = { }
	
	local numIsOpen = 1
	local openTokenIdx = 1
	local closeTokenIdx = 1
	local lastUnclosedOpenToken = openTokenPos[openTokenIdx]
	local lastUnclosedCloseToken = closeTokenPos[closeTokenIdx]
	
	while openTokenIdx <= numTokens and closeTokenIdx <= numTokens do
		
		local curOpenToken = openTokenPos[openTokenIdx]
		local curCloseToken = closeTokenPos[closeTokenIdx]
		local nextOpenToken = openTokenPos[openTokenIdx + 1]
		
		if nextOpenToken == nil then
			numIsOpen = 0
		elseif nextOpenToken < curCloseToken then
			numIsOpen = numIsOpen + 1
			openTokenIdx = openTokenIdx + 1
		else 
			numIsOpen = numIsOpen - 1
			lastUnclosedCloseToken = closeTokenPos[closeTokenIdx]
			closeTokenIdx = closeTokenIdx + 1
		end
		
		if numIsOpen == 0 then
			table.insert(arr, { [1]=lastUnclosedOpenToken, [2]=lastUnclosedCloseToken })
			-- Move to next unclosed open token
			openTokenIdx = openTokenIdx + 1
			lastUnclosedOpenToken = openTokenPos[openTokenIdx]
			lastUnclosedCloseToken = closeTokenPos[closeTokenIdx]
			numIsOpen = numIsOpen + 1
		end
		
	end
	
	return arr
	
end

------------------------------------------------------------------------
-- Auxiliary function
-- For the given token position (integer), determine whether the token position is valid, 
-- i.e. outside imposed limits given in arg
--
-- @param tokenPos 				Integer representing a | token position
-- @param arg					Variable number of arguments
--								Each argument is a Lua table containing imposed limits 
--								where a | token would be invalid
-- returns						Boolean
------------------------------------------------------------------------
function positionIsValid(tokenPos, ...)
	
	local positionIsValid = true
	for i,t in ipairs(arg) do
		for j,obj in ipairs(t) do
			if tokenPos >= obj[1] and tokenPos <= obj[2] then
				positionIsValid = false
				--goto skip
			end
		end
	end
	--::skip::
	return positionIsValid 
	
end

------------------------------------------------------------------------
-- Sub-level function
-- For a portion of wikitext representing the template definition 
-- (i.e. "{{Template}}" or "{{Template|param1|var=namedParam1}}"),
-- extract each numbered and named parameter
-- Output is an Object-like Lua table mapping the template parameters
-- Should be able to deal with nested templates
--
-- @param strTemplate 			String containing wikitext, declaring a template
-- @param templateName			String containing the name of the template
-- returns						Object-like Lua table with each parameter mapped as 
--								key-and-value
------------------------------------------------------------------------
function splitTemplateParameters(strTemplate, templateName)
	
	local params = { }
	
	local unfilteredParamTokenPos = getTokenPositions(strTemplate, "|")
	--mw.log(strTemplate)
	if #unfilteredParamTokenPos == 0 then return params end
	
	local limNestedTemplate = getInvalidPositionLimits(strTemplate, ".{{", "}}.", true)
	local limInterwikiLink = getInvalidPositionLimits(strTemplate, "%[%[", "%]%]")
	local limNowiki = getInvalidPositionLimits(strTemplate, "<nowiki>", "</%s-nowiki>")
	
	local paramTokenPos = { }
	
	for i,tokenPos in ipairs(unfilteredParamTokenPos) do
		local positionIsValid = positionIsValid(tokenPos, limNestedTemplate, limInterwikiLink, limNowiki)
		if positionIsValid then
			table.insert(paramTokenPos, tokenPos)
		end
	end
	
	table.sort(paramTokenPos)
	
	local n = #paramTokenPos
	local countUnnamedParam = 0
	for i = 1, n, 1 do
		
		-- Get template parameter
		local templateParamStart = paramTokenPos[i] + 1
		local templateParamEnd = paramTokenPos[i+1] or len(strTemplate) - 1
		local templateParam = sub(strTemplate, templateParamStart, templateParamEnd-1)
		
		-- Initialize variables
		local paramName = nil
		
		-- Parse named variable if exists and has a valid position
		local parseNamedTemplate = find(templateParam, "=")
		if parseNamedTemplate ~= nil then
			local positionIsValid = positionIsValid(parseNamedTemplate + templateParamStart - 1, limNestedTemplate, limInterwikiLink, limNowiki)
			--mw.log("Start Index of Template Parameter:", templateParamStart, "Index of = token:", parseNamedTemplate + templateParamStart - 1, positionIsValid)
			if positionIsValid then
				paramName = trim(sub(templateParam, 1, parseNamedTemplate-1))
				paramName = tonumber(paramName) or paramName
				templateParam = trim(sub(templateParam, parseNamedTemplate+1))
			end
		end
		
		-- Map template parameter
		if paramName == nil then countUnnamedParam = countUnnamedParam + 1 end
		params[paramName or countUnnamedParam] = templateParam
		
	end
	
	return params
	
end

------------------------------------------------------------------------
-- Sub-level function
-- Group parsed templates and populate with required properties (template contents) 
--
-- @param strWikitext 			Wikitext contents of a page
-- @param arrParsedTemplates 	Output from parseTemplates
-- returns						Complex Object-like Lua table:
--								Each key of this Object-like Lua table corresponds to a 
--								group of templates sharing the same name
--								Each value of this Object-like Lua table is an array-like 
--								Lua table containing:
--									Object-like Lua table with keys "start_pos", "end_pos", 
--									"template_name", "template_contents", "template_params"
------------------------------------------------------------------------
function groupParsedTemplates(strWikitext, arrParsedTemplates)
	local groupedTemplate = { }
	for i,template in ipairs(arrParsedTemplates) do
		
		-- Extract the substring representing the template declaration and get the parsed template parameters
		local templateContents = sub(strWikitext, template["start_pos"], template["end_pos"])
		local templateParams = splitTemplateParameters(templateContents, templateName)
		
		-- Map extracted properties to the template Object-like Lua table
		template["template_contents"] = templateContents
		template["template_params"] = templateParams
		local templateName = replace(templateContents, "^{{([^\n|:}]+)[\n|:}].*", "%1")
		templateName = replace(templateName, "^(%w)", function (firstLetter) return upper(firstLetter) end)
		templateName = replace(templateName, "_", " ")
		
		-- Group to hashmap-like Lua table accordingly
		if groupedTemplate[templateName] == nil then
			groupedTemplate[templateName] = { }
		end
		table.insert(groupedTemplate[templateName], template)
		
	end
	return groupedTemplate
end

------------------------------------------------------------------------
-- Main function
-- Part of exports
-- Parses the contents of the given page and outputs the template, names, positions, and parameters
--
-- @param page_contents 		Wikitext contents of a page
-- returns						Lua table
------------------------------------------------------------------------
function p.extractTemplates(page_contents)
	
	local arrTemplates = parseTemplates(page_contents)
	arrTemplates = groupParsedTemplates(page_contents, arrTemplates)

	return arrTemplates
end

-- ------------------------------- END CODE ---------------------------------------


-- For testing: type "p.test()" in the wiki debug console.
function p.test()
	local test_string = "{{super|{{outer|a|{{inner|1|2}}|b}}|{{inner|3=foo|4=bar}}}}"
	local arrTemplates = p.extractTemplates(test_string)
	mw.log(dump(arrTemplates))
end

function p.testSongboxTemplates()
	
	local page_name = "Nightfall/Wei_love_Yanzi"
	local page_contents = mw.title.new(page_name):getContent()
	
	local timeStart = os.clock()
	local arrGroupedTemplates = parseTemplates(page_contents)
	local timeParsed = os.clock()
	local arrGroupedTemplates = groupParsedTemplates(page_contents, arrGroupedTemplates)
	local timeEnd = os.clock()
	local diffTime = timeEnd - timeStart
	mw.log("Parsed in " .. timeParsed - timeStart .. " s", "Finished in " .. timeEnd - timeStart .. " s")
	
	--mw.log(dump(arrGroupedTemplates))
	
	local arr_infobox_template = arrGroupedTemplates["Infobox Song"]
	local arr_altver_template = arrGroupedTemplates["AlternateVersion"] or { }
	local defaulttitle = arrGroupedTemplates["DISPLAYTITLE"]
	local lowercasetemplate = arrGroupedTemplates["Lowercase"]
	
	mw.log("Infobox Song Templates")
	mw.log( mw.text.jsonEncode(arr_infobox_template) )
	
	mw.log("\nAlternate Version Templates")
	mw.log( mw.text.jsonEncode(arr_altver_template) )
	
	mw.log("\nTitle")
	if defaulttitle ~= nil then mw.log(defaulttitle[1]["template_contents"]) end
	if lowercasetemplate ~= nil then mw.log(lowercasetemplate[1]["template_contents"]) end
	
end

return p