local Config = {}
local Lib = {
  logger = {},
  conf = {
    log_level = false
  },
  Config = Config,
  _VIM_FALSE = 0,
  _VIM_TRUE  = 1,
  ROOT_DIR = nil
}


-- Setup ======================================================
function Lib.setup(config)
  Lib.conf = Config.normalize(config)
end

function Config.normalize(config, existing)
  local conf = existing or {}
  if Lib.is_empty_table(config) then
    return conf
  end

  for k, v in pairs(config) do
    conf[k] = v
  end

  return conf
end
-- ====================================================

-- Helper functions ===============================================================
local function has_value(tab, val)
  for _, value in ipairs(tab) do
    if value == val then
      return true
    end
  end

  return false
end


function Lib.is_empty_table(t)
  if t == nil then return true end
  return next(t) == nil
end

function Lib.is_empty(s)
  return s == nil or s == ''
end

function Lib.ends_with(str, ending)
  return ending == "" or str:sub(-#ending) == ending
end

function Lib.append_slash(str)
  if not Lib.is_empty(str) then
    if not Lib.ends_with(str, "/") then
      str = str.."/"
    end
  end
  return str
end

function Lib.validate_root_dir(root_dir)
  if Lib.is_empty(root_dir) or
    vim.fn.expand(root_dir) == vim.fn.expand(Lib.ROOT_DIR) then
    return Lib.ROOT_DIR
  end

  if not Lib.ends_with(root_dir, "/") then
    root_dir = root_dir.."/"
  end

  if vim.fn.isdirectory(vim.fn.expand(root_dir)) == Lib._VIM_FALSE then
    vim.cmd("echoerr 'Invalid g:auto_session_root_dir. " ..
    "Path does not exist or is not a directory. " ..
    string.format("Defaulting to %s.", Lib.ROOT_DIR))
    return Lib.ROOT_DIR
  else
    Lib.logger.debug("Using custom session dir: "..root_dir)
    return root_dir
  end
end

function Lib.init_dir(dir)
  if vim.fn.isdirectory(vim.fn.expand(dir)) == Lib._VIM_FALSE then
    vim.fn.mkdir(dir, "p")
  end
end

function Lib.init_file(file_path)
  if not Lib.is_readable(file_path) then
    vim.cmd("!touch "..file_path)
  end
end

function Lib.escaped_path(path)
  return path:gsub("/", "\\%%")
end

function Lib.escaped_session_name_from_cwd()
  local cwd = vim.fn.getcwd()
  return cwd:gsub("/", "\\%%")
end

function Lib.legacy_session_name_from_cwd()
  local cwd = vim.fn.getcwd()
  return cwd:gsub("/", "-")
end

function Lib.is_readable(file_path)
  return vim.fn.filereadable(vim.fn.expand(file_path)) ~= Lib._VIM_FALSE
end
-- ===================================================================================


-- Logger =========================================================
function Lib.logger.debug(...)
  if Lib.conf.log_level == 'debug' then
    print(...)
  end
end

function Lib.logger.info(...)
  local valid_values = {'info', 'debug'}
  if has_value(valid_values, Lib.conf.log_level) then
    print(...)
  end
end

function Lib.logger.error(...)
  error(...)
end
-- =========================================================


--[[
Save Table to File
Load Table from File
v 1.0

Lua 5.2 compatible

Only Saves Tables, Numbers and Strings
Insides Table References are saved
Does not save Userdata, Metatables, Functions and indices of these
----------------------------------------------------
table.save( table , filename )

on failure: returns an error msg

----------------------------------------------------
table.load( filename or stringtable )

Loads a table that has been saved via the table.save function

on success: returns a previously saved table
on failure: returns as second argument an error msg
----------------------------------------------------

Licensed under the same terms as Lua itself.
]]--
do
  -- declare local variables
  --// exportstring( string )
  --// returns a "Lua" portable version of the string
  local function exportstring( s )
    return string.format("%q", s)
  end

  --// The Save Function
  function table.save(  tbl,filename )
    local charS,charE = "   ","\n"
    local file,err = io.open( filename, "wb" )
    if err then return err end

    -- initiate variables for save procedure
    local tables,lookup = { tbl },{ [tbl] = 1 }
    file:write( "return {"..charE )

    for idx,t in ipairs( tables ) do
      file:write( "-- Table: {"..idx.."}"..charE )
      file:write( "{"..charE )
      local thandled = {}

      for i,v in ipairs( t ) do
        thandled[i] = true
        local stype = type( v )
        -- only handle value
        if stype == "table" then
          if not lookup[v] then
            table.insert( tables, v )
            lookup[v] = #tables
          end
          file:write( charS.."{"..lookup[v].."},"..charE )
        elseif stype == "string" then
          file:write(  charS..exportstring( v )..","..charE )
        elseif stype == "number" then
          file:write(  charS..tostring( v )..","..charE )
        end
      end

      for i,v in pairs( t ) do
        -- escape handled values
        if (not thandled[i]) then

          local str = ""
          local stype = type( i )
          -- handle index
          if stype == "table" then
            if not lookup[i] then
              table.insert( tables,i )
              lookup[i] = #tables
            end
            str = charS.."[{"..lookup[i].."}]="
          elseif stype == "string" then
            str = charS.."["..exportstring( i ).."]="
          elseif stype == "number" then
            str = charS.."["..tostring( i ).."]="
          end

          if str ~= "" then
            stype = type( v )
            -- handle value
            if stype == "table" then
              if not lookup[v] then
                table.insert( tables,v )
                lookup[v] = #tables
              end
              file:write( str.."{"..lookup[v].."},"..charE )
            elseif stype == "string" then
              file:write( str..exportstring( v )..","..charE )
            elseif stype == "number" then
              file:write( str..tostring( v )..","..charE )
            end
          end
        end
      end
      file:write( "},"..charE )
    end
    file:write( "}" )
    file:close()
  end

  --// The Load Function
  function table.load( sfile )
    local ftables,err = loadfile( sfile )
    if err then return _,err end
    local tables = ftables()
    for idx = 1,#tables do
      local tolinki = {}
      for i,v in pairs( tables[idx] ) do
        if type( v ) == "table" then
          tables[idx][i] = tables[v[1]]
        end
        if type( i ) == "table" and tables[i[1]] then
          table.insert( tolinki,{ i,tables[i[1]] } )
        end
      end
      -- link indices
      for _,v in ipairs( tolinki ) do
        tables[idx][v[2]],tables[idx][v[1]] =  tables[idx][v[1]],nil
      end
    end
    return tables[1]
  end
  -- close do
end

-- ChillCode


return Lib
