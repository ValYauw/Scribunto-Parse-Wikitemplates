# About 
**ParseTemplate** is a Lua-based module for wikis (powered by MediaWiki) that provides a handy way of parsing [wiki templates](https://www.mediawiki.org/wiki/Help:Templates), [variables](https://www.mediawiki.org/wiki/Help:Magic_words#Variables) and [parser functions](https://www.mediawiki.org/wiki/Manual:Parser_functions) from a given portion of wikitext. 

The extension [Scribunto](https://www.mediawiki.org/wiki/Extension:Scribunto) is required to use this module.

Written for the [Vocaloid Lyrics Wiki](https://vocaloidlyrics.fandom.com/wiki/Module:ParseTemplate) to extract information from thousands of pages.

# Quick Start Guide

To start using this module, type the following lines of code in a module page:
```lua
-- Import module
local module = require('Module:ParseTemplate')

-- Extract the actual wikitext string
local page_contents = mw.title.new("EXAMPLE PAGE"):getContent()

-- Parse the templates, variables and parser functions in the wikitext and organize them into a Lua table
local table_of_templates = module.extractTemplates(page_contents)
```

You can then index the templates in <code>table_of_templates</code>:
```lua
-- Index the first invocation of the template 'Template:Foo' parsed in the wikitext
local obj_template = table_of_templates["Foo"][1]

-- Get the contents of this template invocation
print(obj_template["template_contents"])  -- Example output: {{foo|param1|name=param2}}

-- Get the first unnamed parameter of this template invocation
print(obj_template["template_params"][1])  -- Example output: param1

-- Get the named parameter "name" of this template invocation
print(obj_template["template_params"]["name"])  -- Example output: param2
```

To iterate through the templates organized in <code>table_of_templates</code>:
```lua
-- Iterate through each group of template invocations
for template_group_name, arr_templates in ipairs(table_of_templates) do

  -- Iterate through each template in the sub-group
  for i, obj_template in ipairs(arr_templates) do

    -- Iterate through all parameters in each template
    for param_name, param_value in ipairs(obj_template["template_params"]) do
      ...
    end

  end

end
```

You can also use <code>mw.text.jsonEncode</code> to encode <code>table_of_templates</code> into a human-readable JSON string:
```lua
print( mw.text.jsonEncode(table_of_templates) )
```


## Example Usage

Take the example wikitext portion of a page:
<pre>{{Stub}}{{Infobox character
 | title         = Daisy
 | image         = Example.jpg
 | imagecaption  = Daisy, blowing in the wind
 | position      = Supreme flower
 | age           = 2 months
 | status        = Active
 | height        = 5 inches
 | weight        = 20 grams 
}}

lorem ipsum dolor sit amet

==References==
{{Reflist}}
</pre>

<code>extractTemplates</code> will extract the three templates (Stub, Infobox character, and Reflist) in the form of a Lua table as follows:
```lua
table_of_templates = {
  ["Stub"] = {
    [1] = {
	  ["start_pos"] = 1,
	  ["end_pos"] = 8,
	  ["template_contents"] = "{{Stub}}",
	  ["template_name"] = "Stub",
	  ["template_params"] = { }
    }
  },
  ["Infobox character"] = {
    [1] = {
	  ["start_pos"] = 9,
	  ["end_pos"] = 277,
	  ["template_contents"] = [=[{{Infobox character
 | title         = Daisy
 | image         = Example.jpg
 | imagecaption  = Daisy, blowing in the wind
 | position      = Supreme flower
 | age           = 2 months
 | status        = Active
 | height        = 5 inches
 | weight        = 20 grams 
}}]=],
	  ["template_name"] = "Infobox character",
	  ["template_params"] = { 
        ["title"] = "Daisy",
        ["image"] = "Example.jpg",
        ["imagecaption"] = "Daisy, blowing in the wind",
        ["position"] = "Supreme flower",
        ["age"] = "2 months",
        ["status"] = "Active",
        ["height"] = "5 inches",
        ["weight"] = "20 grams"
      }
	}
  },
  ["Reflist"] = {
    [1] = {
	  ["start_pos"] = 323,
	  ["end_pos"] = 333,
	  ["template_contents"] = "{{Reflist}}",
	  ["template_name"] = "Reflist",
	  ["template_params"] = { }
    }
  }
}
```

Which is equivalent to the following JSON data tree:
```js
{
   "Stub":[
      {
         "start_pos":1,
         "end_pos":8,
         "template_contents":"{{Stub}}",
         "template_name":"Stub",
         "template_params":{},
      }
   ],
   "Infobox character":[
      {
         "start_pos":9,
         "end_pos":277,
         "template_contents":`{{Infobox character
 | title         = Daisy
 | image         = Example.jpg
 | imagecaption  = Daisy, blowing in the wind
 | position      = Supreme flower
 | age           = 2 months
 | status        = Active
 | height        = 5 inches
 | weight        = 20 grams 
}}`,
         "template_name":"Infobox character",
         "template_params":{
            "title":"Daisy",
            "image":"Example.jpg",
            "imagecaption":"Daisy, blowing in the wind",
            "position":"Supreme flower",
            "age":"2 months",
            "status":"Active",
            "height":"5 inches",
            "weight":"20 grams"
         }
      }
   ],
   "Reflist":[
      {
         "start_pos":323,
         "end_pos":333,
         "template_contents":"{{Reflist}}",
         "template_name":"Reflist",
         "template_params":{}
      }
   ]
}
```

## Notes

* Templates are grouped based on the template base page name. I.e. separate invocations using the call <code>{{some template}}</code>, <code>{{Some template}}</code>, and <code>{{some_template}}</code> will be grouped into the same group by the name of "Some template".
* Variables and parser functions (such as <code>{{DEFAULTSORT}}</code>) will be grouped based on the base name of the variables/parser functions.
* Because Lua tables are **unordered** by default, order of keys and values in the output may be different than expected.
* This module is able to deal with templates nested within other templates.
* This module is able to deal with characters escaped using the <code>{{=}}</code> & <code>{{!}}</code> magic words as well as characters enclosed within &lt;nowiki&gt; tags.