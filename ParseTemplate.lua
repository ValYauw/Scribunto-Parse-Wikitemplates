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
-- Auxiliary function
-- For given arrays of opening ({{) & closing (}}) token positions and template names, 
-- determine the starting & closing positions of the templates 
-- in the case where the templates are nesting another template within
-- Does not return anything.
--
-- @param arrOpenToken 			Array-like Lua table of opening token positions ({{)
-- @param arrCloseToken			Array-like Lua table of closing token positions (}})
-- @param arrTemplateNames		Array-like Lua table of template names
-- @param arrParsedTemplates	Array-like Lua table of Object-like Lua tables representing 
--								parsed templates
-- returns						nil
------------------------------------------------------------------------
function partitionNestedTemplatePositions(arrOpenToken, arrCloseToken, arrTemplateNames, arrParsedTemplates)
	
	local idx = #arrOpenToken
	while idx > 0 do
		local posOpen = arrOpenToken[idx]
		local templateName = arrTemplateNames[idx]
		for j,posClose in ipairs(arrCloseToken) do
			if posClose > posOpen then
				table.insert(arrParsedTemplates, { start_pos = posOpen, end_pos = posClose, template_name = templateName } )
				table.remove(arrCloseToken, j)
				break
			end
		end
		idx = idx - 1
	end
end

------------------------------------------------------------------------
-- Sub-level function
-- Parse wikitext and extract the templates (e.g. {{TEMPLATE}}) and parser functions 
--	(e.g. {{DEFAULTSORT:}}) in the page 
-- Should be able to get nesting and nested templates
--
-- @param strWikitext 			Wikitext contents of a page
-- returns						Array-like Lua table containing:
--									Object-like Lua table with keys "start_pos", "end_pos",
--									and "template_name"
------------------------------------------------------------------------
function parseTemplates(strWikitext)
	
	local PATTERN_FIND_OPENING_TOKEN = "{{[^{}|:\n]+"
	local PATTERN_FIND_CLOSING_TOKEN = "}}"
	
    local arrOpenToken = { }
    local arrCloseToken = { }
    local arrTemplateNames = { }
    local arrParsedTemplates = { }
    
    local lastOpenTokenIdx = 1
    local openTokenIdx, templateDecIdx = find(strWikitext, PATTERN_FIND_OPENING_TOKEN, lastOpenTokenIdx)
    local d, closeTokenIdx = 0, 0
    local lastCloseTokenIdx = (openTokenIdx or -2) + 2
    while openTokenIdx ~= nil do
    	
    	-- Search for the nearest closing token position
    	d, closeTokenIdx = find(strWikitext, PATTERN_FIND_CLOSING_TOKEN, lastCloseTokenIdx)
    	if closeTokenIdx ~= nil then 
    		lastCloseTokenIdx = closeTokenIdx + 1
    		-- Add the pair of found opening & closing token position
    		table.insert(arrOpenToken, openTokenIdx)
    		table.insert(arrCloseToken, closeTokenIdx)
    		-- Get the template name
    		local templateName = sub(strWikitext, openTokenIdx + 2, templateDecIdx)
    		table.insert(arrTemplateNames, templateName)
    	end
    	
    	-- Move to next token
    	lastOpenTokenIdx = templateDecIdx + 1
    	openTokenIdx, templateDecIdx = find(strWikitext, PATTERN_FIND_OPENING_TOKEN, lastOpenTokenIdx)
    	
    end
    
    local numOpenTokens = #arrOpenToken
    local numCloseTokens = #arrCloseToken
    
    -- From the array of token positions, process these positions to get the starting and ending positions of each template
    -- (including nesting & nested templates)
    idx = 1
    terminateIdx = numOpenTokens
    while idx <= terminateIdx do
    	local openTokenPos = arrOpenToken[idx]
    	local closeTokenPos = arrCloseToken[idx]
    	local templateName = arrTemplateNames[idx]
    	local nextOpenTokenPos = arrOpenToken[idx+1]
    	-- For the simple case where no template is nested inside the current template, add that template immediately
    	if closeTokenPos > openTokenPos and (nextOpenTokenPos == nil or closeTokenPos < nextOpenTokenPos) then
    		table.insert(arrParsedTemplates, { start_pos = openTokenPos, end_pos = closeTokenPos, template_name = templateName })
    	-- Otherwise process nested templates
    	else
    		local len_slice = 0
    		repeat
    			len_slice = len_slice + 1
    			closeTokenPos = arrCloseToken[idx + len_slice]
    			nextOpenTokenPos = arrOpenToken[idx + len_slice + 1]
    		until (nextOpenTokenPos == nil or nextOpenTokenPos > closeTokenPos)
    		len_slice = len_slice + 1
    		local slicedArrOpenToken = slice(arrOpenToken, idx, len_slice)
    		local slicedArrCloseToken = slice(arrCloseToken, idx, len_slice)
    		local slicedArrTemplateNames = slice(arrTemplateNames, idx, len_slice)
    		partitionNestedTemplatePositions(slicedArrOpenToken, slicedArrCloseToken, slicedArrTemplateNames, arrParsedTemplates)
    		idx = idx + len_slice - 1
    	end
    	idx = idx + 1
    end
	
	return arrParsedTemplates

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
		
		-- Process parsed template names (remove trailing whitespace, force first character to be upper case, convert underscore to space)
		local templateName = trim(template["template_name"])
		templateName = replace(templateName, "^(%w)", function (firstLetter) return upper(firstLetter) end)
		templateName = replace(templateName, "_", " ")
		
		-- Extract the substring representing the template declaration and get the parsed template parameters
		local templateContents = sub(strWikitext, template["start_pos"], template["end_pos"])
		local templateParams = splitTemplateParameters(templateContents, templateName)
		
		-- Map extracted properties to the template Object-like Lua table
		template["template_contents"] = templateContents
		template["template_params"] = templateParams
		
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
	local arrGroupedTemplates = p.extractTemplates(page_contents)
	local timeEnd = os.clock()
	local diffTime = timeEnd - timeStart
	mw.log("Finished in " .. diffTime .. " s")
	
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