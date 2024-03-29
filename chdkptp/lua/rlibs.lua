--[[
 Copyright (C) 2010-2020 <reyalp (at) gmail dot com>
  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License version 2 as
  published by the Free Software Foundation.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

]]
--[[
simple library system for building remote commands
chunks of source code to be used remotely
can be used with chdku.exec
TODO some of these are duplicated with local code, but we don't yet have an easy way of sharing them
should allow loading rlib source from local files
TODO would be good to minify
TODO passing compiled chunks might be better but our lua configurations are different
]]
local rlibs = {
	libs={},
}
--[[
register{
	name='libname'
	depend='lib'|{'lib1','lib2'...}, -- already registered rlibs this one requires (cyclic deps not allowed)
	code='', -- main lib code.
}
]]
function rlibs:register(t)
	-- for convenience, single lib may be given as string
	if type(t.depend) == 'string' then
		t.depend = {t.depend}
	elseif type(t.depend) == 'nil' then
		t.depend = {}
	elseif type(t.depend) ~= 'table' then
		error('expected dependency table or string')
	end
	if type(t.code) ~= 'string' then
		error('expected code string')
	end
	if type(t.name) ~= 'string' then
		error('expected name string')
	end
	t.lines = 0 
	for c in string.gmatch(t.code,'\n') do
		t.lines = t.lines + 1
	end

	for i,v in ipairs(t.depend) do
		if not self.libs[v] then
			errf('%s missing dep %s\n',t.name,v)
		end
	end
	self.libs[t.name] = t
end

--[[
register an array of libs
]]
function rlibs:register_array(t)
	for i,v in ipairs(t) do
		self:register(v)
	end
end

--[[
add deps for a single lib
]]
function rlibs:build_single(build,name)
	local lib = self.libs[name]
	if not lib then
		errf('unknown lib %s\n',tostring(name))
	end
	-- already added
	if build.map[name] then
		return
	end
	for i,dname in ipairs(lib.depend) do
		self:build_single(build,dname)
	end
	build.map[name]=lib
	table.insert(build.list,lib)
end
--[[
return an object containing the libs with deps resolved
obj=rlibs:build('name'|{'name1','name2',...})
]]
-- helper for returned object
local function rlib_get_code(build)
	local code=""
	for i,lib in ipairs(build.list) do
		code = code .. lib.code .. '\n'
	end
	return code
end
function rlibs:build(libnames)
	-- single can be given as string, 
	-- nil is allowed, returns empty object
	if type(libnames) == 'string' or type(libnames) == 'nil' then
		libnames={libnames}
	elseif type(libnames) ~= 'table' then
		error('rlibs:build_list expected string or table for libnames')
	end
	local build={
		list={},
		map={},
		code=rlib_get_code,
	}
	for i,name in ipairs(libnames) do
		self:build_single(build,name)
	end
	return build
end
--[[
return a string containing all the required rlib code
code=rlibs:build('name'|{'name1','name2',...})
]]
function rlibs:code(names)
	local build = self:build(names)
	return build:code();
end

rlibs:register_array{
--[[
mostly duplicated from util.serialize
global defaults can be changed from code
]]
{
	name='serialize',
	code=[[
serialize_r = function(v,opts,r,seen,depth)
	local vt = type(v)
	if vt == 'nil' or  vt == 'boolean' or vt == 'number' then
		table.insert(r,tostring(v))
		return
	end
	if vt == 'string' then
		table.insert(r,string.format('%q',v))
		return 
	end
	if vt == 'table' then
		if not depth then
			depth = 1
		end
		if depth >= opts.maxdepth then
			error('serialize: max depth')
		end
		if not seen then
			seen={}
		elseif seen[v] then 
			if opts.err_cycle then
				error('serialize: cycle')
			else
				table.insert(r,'"cycle:'..tostring(v)..'"')
				return 
			end
		end
		seen[v] = true
		table.insert(r,'{')
		local maxn=#v
		if opts.compact_arrays and maxn > 0 then
			if opts.pretty then
				table.insert(r,'\n'..string.rep(' ',depth))
			end
			for k,v1 in ipairs(v) do
				serialize_r(v1,opts,r,seen,depth+1)
				table.insert(r,',')
				if opts.pretty and type(v1) == 'table' then 
					table.insert(r,'\n'..string.rep(' ',depth))
				end
			end
		end

		for k,v1 in pairs(v) do
			if not opts.compact_arrays or type(k) ~= 'number' or k < 1 or k > maxn then
				if opts.pretty then
					table.insert(r,'\n'..string.rep(' ',depth))
				end
				if not opts.bracket_keys and type(k) == 'string' and string.match(k,'^[_%a][%a%d_]*$') then
					table.insert(r,k)
				else
					table.insert(r,'[')
					serialize_r(k,opts,r,seen,depth+1)
					table.insert(r,']')
				end
				table.insert(r,'=')
				serialize_r(v1,opts,r,seen,depth+1)
				table.insert(r,',')
			end
		end
		if r[#r] == ',' then
			table.remove(r)
		end
		if opts.pretty then
			table.insert(r,'\n'..string.rep(' ',depth-1))
		end
		table.insert(r,'}')
		return
	end
	if opts.err_type then
		error('serialize: unsupported type ' .. vt, 2)
	else
		table.insert(r,'"'..tostring(v)..'"')
	end
end
serialize_defaults = {
	maxdepth=10,
	err_type=true,
	err_cycle=true,
	pretty=false,
	bracket_keys=false,
	compact_arrays=true,
}
function serialize(v,opts)
	if opts then
		for k,v in pairs(serialize_defaults) do
			if not opts[k] then
				opts[k]=v
			end
		end
	else
		opts=serialize_defaults
	end
	local r={}
	serialize_r(v,opts,r)
	return table.concat(r)
end
]],
},
--[[
unserialize, copied from util 5.1 code
useful if you are sending messages with lua data structures
]]
{
	name='unserialize',
	code=[[
function unserialize(s)
	local f,err=loadstring('return ' .. s)
	if not f then
		return false, err
	end
	setfenv(f,{}) -- empty fenv
	local status,r=pcall(f)
	if status then
		return r
	end
	return false,r
end
]]
},
--[[
mt_inherit from util
]]
{
	name='mt_inherit',
	code=[[
function mt_inherit(t,base)
	local mt={
		__index=function(table, key)
			return base[key]
		end
	}
	setmetatable(t,mt)
	return t
end
]],
},
--[[
extend_table from util
note deep will fail unless you include extend_table_r
]]
{
	name='extend_table',
	code=[[
function extend_table(target,source,deep)
	if type(target) ~= 'table' then
		error('extend_table: target not table')
	end
	if source == nil then
		return target
	end
	if type(source) ~= 'table' then 
		error('extend_table: source not table')
	end
	if source == target then
		error('extend_table: source == target')
	end
	if deep then
		return extend_table_r(target, source)
	else 
		for k,v in pairs(source) do
			target[k]=v
		end
		return target
	end
end
]],
},
--[[
recursive version of extend_table
not meant to be used on its own 
depends are intentially weird, requiring this will pull in extend_table
]]
{
	name='extend_table_r',
	depend='extend_table',
	code=[[
extend_table_max_depth = 10
function extend_table_r(target,source,seen,depth) 
	if not seen then
		seen = {}
	end
	if not depth then
		depth = 1
	end
	if depth > extend_table_max_depth then
		error('extend_table: max depth');
	end
	-- a source could have refernces to the target, don't want to do that
	seen[target]=true
	if seen[source] then
		error('extend_table: cycles');
	end
	seen[source]=true
	for k,v in pairs(source) do
		if type(v) == 'table' then
			if type(target[k]) ~= 'table' then
				target[k] = {}
			end
			extend_table_r(target[k],v,seen,depth+1)
		else
			target[k]=v
		end
	end
	return target
end
]],
},
-- override default table serialization for messages
{
	name='serialize_msgs',
	depend='serialize',
	code=[[
	usb_msg_table_to_string=serialize
]],
},
--[[
serialize mem use testing
]]
--!return con:execwait([[return sertest({a='a',b='b',t={1,2,3,{test='the quick brown fox',1,2,3,4,5,6,7,8,9,10,11,1 2,13,14,14},{}}},serialize)]],{libs={'serialize_msgs','sertest'}})
{
	name='sertest',
	depend='serialize_msgs',
	code=[[
function memstats(name)
	local t={
		name=name,
		count=collectgarbage('count')
	}
	local m=get_meminfo()
	t.free_size=m.free_size
	t.free_block_max_size=m.free_block_max_size
	return t
end

function sertest(data,func)
	collectgarbage('collect')
	local t={
		memstats('before')
	}
	t.r=func(data)
	table.insert(t,memstats('after'))
	collectgarbage('collect')
	table.insert(t,memstats('collect'))
	return t
end
]],
},

--[[
join a path with / as needed
]]
{
	name='joinpath',
	code=[[
function joinpath(...)
	local parts={...}
	if #parts < 2 then
		error('joinpath requires at least 2 parts',2)
	end
	local r=parts[1]
	for i = 2, #parts do
		local v = string.gsub(parts[i],'^/','')
		if not string.match(r,'/$') then
			r=r..'/'
		end
		r=r..v
	end
	return r
end
]],
},
--[[
basename_cam from fsutil
]]
{
	name='basename',
	code=[[
function basename(path,sfx)
	if not path then
		return nil
	end
	if path == 'A/' then
		return nil
	end
	local s,e,bn=string.find(path,'([^/]+)/?$')
	if not s then
		return nil
	end
	if sfx and string.len(sfx) < string.len(bn) then
		if string.sub(bn,-string.len(sfx)) == sfx then
			bn=string.sub(bn,1,string.len(bn) - string.len(sfx))
		end
	end
	return bn
end
]],
},
--[[
dirname_cam from fsutil
note A/ is ambiguous
]]
{
	name='dirname',
	code=[[
function dirname(path)
	if not path then
		return nil
	end
	if path == 'A/' then
		return path
	end
	-- remove trailing blah/?
	local dn=string.gsub(path,'[^/]+/*$','')
	-- invalid, 
	if dn == '' then
		return nil
	end
	-- remove any trailing /
	dn = string.gsub(dn,'/*$','')
	if dn == 'A' then
		return 'A/'
	end
	-- all /, invalid
	if dn == '' then
		return nil
	end
	return dn
end
]],
},
--[[
splitpath_cam from util
]]
{
	name='splitpath',
	depend={'basename','dirname'},
	code=[[
	local parts={}
function splitpath(path)
	while true do
		local part=basename(path)
		path = dirname(path)
		table.insert(parts,1,part)
		if path == 'A/' then
			table.insert(parts,1,path)
			return parts
		end
		if path == nil then
			return parts
		end
	end
end
]],
},
--[[
make multiple levels of directories, as needed
modified from fsutil
]]
{
	name='mkdir_m',
	depend={'splitpath','joinpath'},
	code=[[
function mkdir_m(path)
	local st = os.stat(path)
	if st then
		if st.is_dir then
			return true
		end
		return false,'path exists, not directory'
	end
	local parts = splitpath(path)
	local p=parts[1]
	for i=2, #parts do
		p = joinpath(p,parts[i])
		local st = os.stat(p)
		if not st then
			local status,err = os.mkdir(p)
			if not status then
				return false,err
			end
		elseif not st.is_dir then
			return false,'path exists, not directory'
		end
	end
	return true
end
]],
},
--[[
function to batch stuff in groups of messages
each batch is sent as a numeric array
b=msg_batcher{
	batchsize=num, -- items per batch
	batchpause=num -- sleep after each batch, to allow client to empty queue, default=unset=none
	batchgc=string -- 'collect' or 'step', if set, collectgarbage is called with this on each flush
	timeout=num, -- message timeout
	dbgmem=bool --  return memory info in data._dbg
}
TODO should check free memory and force collect/flush if low, but bad for cameras without firmware meminfo
call
b:write(value) adds items and sends when batch size is reached
b:flush() sends any remaining items
]]
{
	name='msg_batcher',
	depend={'serialize_msgs','extend_table'},
	code=[[
function msg_batcher(opts)
	local t = extend_table({
		batchsize=50,
		batchgc='step',
		timeout=100000,
	},opts)
	t.data={}
	t.n=0
	if t.dbgmem then
		t.init_free = get_meminfo().free_block_max_size
		t.init_count = collectgarbage('count')
	end
	t.write=function(self,val)
		self.n = self.n+1
		self.data[self.n]=val
		if self.n >= self.batchsize then
			return self:flush()
		end
		return true
	end
	t.flush = function(self)
		if self.n > 0 then
			if self.dbgmem then
				local count=collectgarbage('count')
				local free=get_meminfo().free_block_max_size
				self.data._dbg=string.format("count %d (%d) free %d (%d)",
					count, count - self.init_count, free, self.init_free-free)
			end
			if not write_usb_msg(self.data,self.timeout) then
				return false
			end
			self.data={}
			self.n=0
			if self.batchgc then
				collectgarbage(self.batchgc)
			end
			if self.batchpause then
				sleep(self.batchpause)
			end
		end
		return true
	end
	return t
end
]],
},
--[[
retrieve a directory listing of names, batched in messages
]]
{
	name='ls_simple',
	depend='msg_batcher',
	code=[[
function ls_simple(path)
	local b=msg_batcher()
	local t,err=os.listdir(path)
	if not t then
		return false,err
	end
	for i,v in ipairs(t) do
		if not b:write(v) then
			return false
		end
	end
	return b:flush()
end
]],
},
--[[
object to aid interating over files and directories
status,err=fs_iter.run({paths},opts)
opts={
	callback=function(self)
	end_callback=function(self,status,msg)
	listall=bool -- pass to os.listdir; currently broken, stat on . or .. fails
	use_idir=bool -- use os.idir if available, avoids out of memory / timeouts on large dirs, but may have recursion limits
	-- users may add their own methods or members
})
self in callbacks is the fs_iter object, merged with opts
callback is called on each file/directory 
must return true to continue processing, or false optionally followed by an error message on error
the following are available to callback
self.cur={
	st=<stat information>
	full=<full path and filename as string>
	path=<array of {initial path, path components recursed into,..., name}>
	name=<basename>
}
in the case of the root directory full='A/' and name='A/'
self.rpath an array of path elements representing the directories recursed into
self:depth() depth of recursion, 0 for initial paths
self:can_recurse() to check if the current items is valid to recurse into
self:recurse() to recurse into a directory
]]
{
	name='fs_iter',
	depend={'serialize_msgs','joinpath','basename','mt_inherit','extend_table'},
	code=[[
fs_iter={}

function fs_iter:depth()
	return #self.rpath
end

function fs_iter:can_recurse()
	if not self.cur.st.is_dir or self.cur.name == '.' or self.cur.name == '..' then
		return false
	end
	return true
end

function fs_iter:recurse()
	if not self:can_recurse() then
		return false
	end
	table.insert(self.rpath,self.cur.path[#self.cur.path])
	local save_cur = self.cur
	local status,err = self:singledir()
	self.cur = save_cur
	table.remove(self.rpath)
	return status,err
end

function fs_iter:singleitem(path)
	local st,err=os.stat(path)
	if not st then
		return false,err
	end
	self.cur={st=st,full=path}
	if path == 'A/' then
		self.cur.name = 'A/'
	else
		self.cur.name = basename(path)
	end
	if #self.rpath == 0 then
		self.cur.path = {path}
	else
		self.cur.path = {unpack(self.rpath)}
		table.insert(self.cur.path,self.cur.name)
	end
	return self:callback()
end

function fs_iter:singledir()
	local cur_dir = self.cur.full
	if self.use_idir and os.idir then
		for name in os.idir(cur_dir,self.listall) do
			local status, err = self:singleitem(joinpath(cur_dir,name))
			if not status then
				return false,err
			end
		end
	else
		local t,err=os.listdir(cur_dir,self.listall)
		if not t then
			return false,err
		end
		for i,name in ipairs(t) do
			local status, err = self:singleitem(joinpath(cur_dir,name))
			if not status then
				return false,err
			end
		end
	end
	return true
end

function fs_iter:end_callback(status,msg)
	return status,msg
end

function fs_iter.run(paths,opts)
	local t=extend_table({},opts)
	mt_inherit(t,fs_iter)

	for i,path in ipairs(paths) do
		t.rpath={}
		local status,err=t:singleitem(path)
		if not status then
			return t:end_callback(false,err)
		end
	end
	return t:end_callback(true)
end
]],
},
--[[
process directory tree with matching
status,err = find_files(paths,opts,func)
paths=<array of paths to process>
opts={
	fmatch='<pattern>', -- match on full path of files, default any (NOTE can match on filename with /<match>$)
	dmatch='<pattern>', -- match on names of directories, default any 
	rmatch='<pattern>', -- recurse into directories matching, default any 
	dirs=true, -- pass directories to func. otherwise only files sent to func, but dirs are still recursed
	dirsfirst=false, -- process directories before contained files
	maxdepth=100, -- maxium depth of directories to recurse into, 0=just process paths passed in, don't recurse
	martians=bool, -- process non-file, not directory items (vol label,???) default false
	batchsize=20, -- passed to msg_batcher, if used
	use_idir, -- use  passed to fs_iter
}
func defaults to batching the full path of each file
unless dirsfirst is set, directories will be recursed into before calling func on the containing directory
TODO
match on stat fields (newer, older etc)
match by path components e.g. /foo[ab]/bar/.*%.lua
]]
{
	depend={'fs_iter','msg_batcher','extend_table'},
	name='find_files',
	code=[[
function find_files_all_fn(di,opts)
	return di:ff_bwrite(di.cur)
end

function find_files_fullname_fn(di,opts)
	return di:ff_bwrite(di.cur.full)
end

function find_files(paths,opts,func)
	if not func then
		func=find_files_fullname_fn
	end
	opts=extend_table({
		dirs=true,
		dirsfirst=false,
		maxdepth=100,
		batchsize=20,
	},opts)

	return fs_iter.run(paths,{
		use_idir=opts.use_idir,
		ff_check_match=function(self,opts)
			if self.cur.st.is_file then
				return not opts.fmatch or string.match(self.cur.full,opts.fmatch)
			end
			if self.cur.st.is_dir then
				return not opts.dmatch or string.match(self.cur.full,opts.dmatch)
			end
			if opts.martians then
				return true
			end
			return false
		end,
		ff_bwrite=function(self,data)
			if not self.ff_batcher then
				self.ff_batcher = msg_batcher({
					batchsize=opts.batchsize,
					batchpause=opts.batchpause,
					batchgc=opts.batchgc,
					dbgmem=opts.dbgmem})
			end
			return self.ff_batcher:write(data)
		end,
		ff_bflush=function(self)
			if not self.ff_batcher then
				return true
			end
			return self.ff_batcher:flush()
		end,
		ff_func=func,
		ff_item=function(self,opts)
			if not self:ff_check_match(opts) then
				return true
			end
			return self:ff_func(opts)
		end,
		callback=function(self)
			if self.cur.st.is_dir then
				if opts.dirs and opts.dirsfirst then
					local status,err = self:ff_item(opts)
					if not status then
						return false,err
					end
				end
				if self:depth() < opts.maxdepth and self:can_recurse() then
					if not opts.rmatch or string.match(self.cur.name,opts.rmatch) then
						local status,err = self:recurse()
						if not status then
							return false,err
						end
					end
				end
				if opts.dirs and not opts.dirsfirst then
					local status,err = self:ff_item(opts)
					if not status then
						return false,err
					end
				end
			else
				local status,err = self:ff_item(opts)
				if not status then
					return false,err
				end
			end
			return true
		end,
		end_callback=function(self,status,err)
			if not status then
				self:ff_bflush()
				return false,err
			end
			return self:ff_bflush()
		end
	})
end
]],
},
--[[
camera side support for mdownload
]]
{
	depend={'find_files'},
	name='ff_mdownload',
	code=[[
function ff_mdownload_fn(self,opts)
	if #self.rpath == 0 and self.cur.st.is_dir then
		return true
	end
	return self:ff_bwrite(self.cur)
end

function ff_mdownload(paths,opts)
	return find_files(paths,opts,ff_mdownload_fn)
end
]],
},
--[[
camera side support for mdelete
]]
{
	depend={'find_files'},
	name='ff_mdelete',
	code=[[
function ff_mdelete_fn(self,opts)
	local status,msg
	if self.cur.full == 'A/' or (opts.skip_topdirs and self.cur.st.is_dir == true and #self.rpath == 0) then
		return self:ff_bwrite({file=self.cur.full,status=true,msg='skipped'})
	end
	if not opts.pretend then
		status,msg=os.remove(self.cur.full)
		if not status and not opts.ignore_errors then
			self:ff_bwrite({file=self.cur.full,status=status,msg=msg})
			return false, msg
		end
	else
		status=true
	end
	return self:ff_bwrite({file=self.cur.full,status=status,msg=msg})
end

function ff_mdelete(paths,opts)
	return find_files(paths,opts,ff_mdelete_fn)
end
]],
},
--[[
image directory list / download
additional options
start_paths    - list of initial paths/directories, default to A/DCIM
imgnum_min=N   - lowest image number to return
imgnum_max=N   - highest image number to return
dirnum_min=N   - lowest image number to return
dirnum_max=N   - highest image number to return
lastimg=N|true - set imgnum_* to return the last N images based on get_exp_count().
                 Does not handle counter rollover or folder change
TODO dirnum is inefficient, since it checks every file rather than at recurse time
]]
{
	depend={'find_files'},
	name='ff_imglist',
	code=[[
function ff_imglist_fn(self,opts)
	if #self.rpath == 0 and self.cur.st.is_dir then
		return true
	end
	if opts.imgnum_min or opts.imgnum_max then
		local imgnum = string.match(self.cur.name,'%a%a%a_(%d%d%d%d)%.%w%w%w$')
		if not imgnum then
			return true
		end
		imgnum = tonumber(imgnum)
		if opts.imgnum_min and imgnum < opts.imgnum_min then
			return true
		end
		if opts.imgnum_max and imgnum > opts.imgnum_max then
			return true
		end
	end
	if opts.dirnum_min or opts.dirnum_max then
		local dirnum = string.match(self.cur.full,'/(%d%d%d)[^/]*/'..self.cur.name)
		if not dirnum then
			return true
		end
		dirnum = tonumber(dirnum)
		if opts.dirnum_min and dirnum < opts.dirnum_min then
			return true
		end
		if opts.dirnum_max and dirnum > opts.dirnum_max then
			return true
		end
	end
	return self:ff_bwrite(self.cur)
end

function ff_imglist(opts)
	if opts.lastimg then
		if type(opts.lastimg) ~= 'number' then
			opts.lastimg = 1
		end
		opts.imgnum_max=get_exp_count()
		if opts.lastimg < opts.imgnum_max then
			opts.imgnum_min = opts.imgnum_max - opts.lastimg + 1
		else
			opts.imgnum_min = 1
		end
		opts.start_paths={get_image_dir()}
	end

	if not opts.start_paths then
		opts.start_paths={'A/DCIM'}
	end
	return find_files(opts.start_paths,opts,ff_imglist_fn)
end
]],
},
--[[
TODO rework this to a general iterate over directory function
sends file listing as serialized tables with write_usb_msg
returns true, or false,error message
opts={
	stat=bool|{table}|'/'|'*',
	listall=bool, 
	msglimit=number,
	match="pattern",
	dirsonly=bool
}
stat
	false/nil, return an array of names without stating at all
	'/' return array of names, with / appended to dirs
	'*" return array of stat results, plus name="name"
	{table} return stat fields named in table (TODO not implemented)
msglimit
	maximum number of items to return in a message
	each message will contain a table with partial results
	default 50
match
	pattern, file names matching with string.match will be returned
listall 
	passed as second arg to os.listdir / idir
dirsonly
    only list directories, error if path is a file

Prior to CHDK 1.3 may run out of memory or cause PTP timeouts with large dirs
msglimit can help but os.listdir itself could use all memory
TODO message timeout is not checked
]]
{
	name='ls',
	depend={'msg_batcher','joinpath'},
	code=[[
function ls_single(opts,b,path,v)
	if not opts.match or string.match(v,opts.match) then
		if opts.stat then
			local st,msg=os.stat(joinpath(path,v))
			if not st then
				return false,msg
			end
			if opts.stat == '/' then
				if st.is_dir then
					b:write(v .. '/')
				else 
					b:write(v)
				end
			elseif opts.stat == '*' then
				st.name=v
				b:write(st)
			end
		else
			b:write(v)
		end
	end
	return true
end

function ls(path,opts_in)
	local opts={
		msglimit=50,
		msgtimeout=100000,
		dirsonly=true
	}
	if opts_in then
		for k,v in pairs(opts_in) do
			opts[k]=v
		end
	end
	local st, err = os.stat(path)
	if not st then
		return false, err
	end

	local b=msg_batcher{
		batchsize=opts.msglimit,
		timeout=opts.msgtimeout
	}

	if not st.is_dir then
		if opts.dirsonly then
			return false, 'not a directory'
		end
		if opts.stat == '*' then
			st.name=path
			b:write(st)
		else
			b:write(path)
		end
		b:flush()
		return true
	end

	if os.idir then
		for v in os.idir(path,opts.listall) do
			local status,err=ls_single(opts,b,path,v)
			if not status then
				return false, err
			end
		end
	else
		local t,msg=os.listdir(path,opts.listall)
		if not t then
			return false,msg
		end
		for i,v in ipairs(t) do
			local status,err=ls_single(opts,b,path,v)
			if not status then
				return false, err
			end
		end
	end
	b:flush()
	return true
end
]],
},
--[[
wait for function to return true or timeout
]]
{
	name='wait_timeout',
	depend={'extend_table'},
	code=[[
function rlib_wait_timeout(func,opts)
	opts=extend_table({
		timeout=1000,
		timeout_error=true,
		sleep=10,
		msg='timeout',
	},opts)
	local timeout_tick = get_tick_count() + opts.timeout
	repeat
		if func() then
			return true
		end
		sleep(opts.sleep)
	until get_tick_count() > timeout_tick
	if opts.timeout_error then
		error(opts.msg)
	end
	return false
end
]],
},
--[[
wait for file to exist or timeout
]]
{
	name='wait_file',
	depend={'extend_table','wait_timeout'},
	code=[[
function rlib_wait_file(name,opts)
	opts = extend_table({
		wait_size_stable=true,
		timeout=2000,
		sleep=30,
		msg=string.format('wait_file %s timeout',name)
	},opts)

	return rlib_wait_timeout(function()
		local st = os.stat(name)
		if st then
			if not opts.wait_size_stable or (prev_st and st.size == prev_st.size) then
				return true
			else
				prev_st = st
			end
		end
	end,opts)
end
]],
},

--[[
focus override module (enable_override only works CHDK >= 1.4)
]]
{
	name='focus',
	code=[=[
focus={
	mode_names={'AF','AFL','MF'},
	valid_modes={}, -- table of name=true
	modes={}, -- array of usable mode names
}
-- initialize valid modes for sd over
function focus:init()
	if self.inited then
		return
	end
	-- bits: 1 = AF, 2 = AFL, 3 = MF
	local modes=0
	if type(get_sd_over_modes) == 'function' then
		modes=get_sd_over_modes()
	end
	self.modes={}
	for i=1,3 do
		if bitand(1,modes) == 1 then
			table.insert(self.modes,self.mode_names[i])
		end
		modes = bitshru(modes,1)
	end
	for i,m in ipairs(self.modes) do
		self.valid_modes[m]=true
	end
	self.inited=true
end
-- get current AF/AFL/MF state
function focus:get_mode()
	if get_prop(require'propcase'.AF_LOCK) == 1 then
		return 'AFL'
	end
	if get_prop(require'propcase'.FOCUS_MODE) == 1 then
		return 'MF'
	end
	return 'AF'
end
--[[
set AF/AFL/MF state
mode is one of 'AF','MF', 'AFL'
unless force is true, does not call set functions if already in desired state
]]
function focus:set_mode(mode,force)
	local cur_mode = self:get_mode()
	if not force and cur_mode == mode then
		return
	end
	if mode == 'AF' then
		if cur_mode == 'MF' then
			set_mf(false)
		elseif cur_mode == 'AFL' then
			set_aflock(false)
		end
	elseif mode == 'AFL' then
		if cur_mode == 'MF' then
			set_mf(false)
		end
		set_aflock(true)
	elseif mode == 'MF' then
		if cur_mode == 'AFL' then
			set_aflock(false)
		end
		set_mf(true)
	end
end
--[[
set to a mode that allows override, defaulting to prefmode, or the current mode if not set
]]
function focus:enable_override(prefmode)
	self:init()
	-- override not supported or in playback
	if #self.modes == 0 or not get_mode() then
		return false
	end
	-- no pref, default to overriding in current mode if possible
	if not prefmode then
		prefmode=self:get_mode()
	end
	local usemode
	if self.valid_modes[prefmode] then
		usemode = prefmode
	else
		-- if pref is MF or AFL, prefer locked if available
		if prefmode == 'MF' and self.valid_modes['AFL'] then
			usemode = 'AFL'
		elseif prefmode == 'AFL' and self.valid_modes['MF'] then
			usemode = 'MF'
		elseif self.valid_modes[self:get_mode()] then
			usemode = self:get_mode()
		else
 			-- no pref, use first available
			usemode = self.modes[1]
		end
	end
	self:set_mode(usemode)
	return true
end
function focus:set(dist)
	set_focus(dist)
end
]=],
},
--[[
get drive mode / self timer information
returns: {
	drive_mode=<n> -- PROPCASE_DRIVE_MODE prop value
	timer_mode=<n> -- PROPCASE_TIMER_MODE value, or 0 if not defined
	is_cont=<bool> -- any continuous mode
	is_cont_af=<bool> -- continuous with AF
	is_timer=<bool> -- any self timer mode
	is_timer_cust=<bool> -- custom timer
	is_timer_face=<bool> -- face timer
	is_std=<bool> -- standard, not in cont or face timer, but may be in other special shooting modes like wink / smile detect
	timer_shots=<n> -- custom timer shots (not available on all cams, nil if not supported or not in cust timer)
	timer_delay=<n> -- custom timer delay (not available on all cams, nil if not supported or not in cust timer)
}
]]
{
	name='drive_mode_info',
	code=[[
function rlib_get_drive_mode_info()
	local props=require'propcase'
	local r = {}
	r.drive_mode = get_prop(props.DRIVE_MODE)
	if props.TIMER_MODE then
		r.timer_mode = get_prop(props.TIMER_MODE)
	else
		if get_propset() == 1 then
			r.timer_mode = get_prop(219) -- not present in older propset.h
		else
			r.timer_mode = 0
		end
	end
	if get_propset() == 1 then
		if r.drive_mode == 1 then
			r.is_cont = true
		end
		if r.drive_mode == 2 then
			r.is_timer = true
			if r.timer_mode == 2 then
				r.is_timer_cust = true
			end
		end
	elseif get_propset() >= 2 then
		if r.drive_mode == 1 then
			r.is_cont = true
		elseif r.drive_mode == 2 then
			r.is_cont = true
			r.is_cont_af = true
		end
		if r.timer_mode > 0 then
			r.is_timer = true
			if r.timer_mode == 3 then
				r.is_timer_cust = true
			elseif r.timer_mode == 4 then
				r.is_timer_face = true
			end
		end
	end
	-- face can also have a shots count, but a different prop in most propsets
	if r.is_timer_cust then
		-- not props on all cams
		if props.TIMER_SHOTS then
			r.timer_shots = get_prop(props.TIMER_SHOTS)
		end
		if props.TIMER_DELAY then
			r.timer_delay = get_prop(props.TIMER_DELAY)
		end
	end
	r.is_std = not (r.is_timer or r.is_cont)
	return r
end
]],
},
--[[
support for cli shoot command, set exposure params
TODO could check that ISO mode gets set, esp for 1.2 which ignores unknown values
]]
{
	name='rlib_shoot_common',
	depend={'focus'},
	code=[[
function rlib_shoot_init_exp(opts)
	if opts.tv then
		set_tv96_direct(opts.tv)
	end
	if opts.sv then
		set_sv96(opts.sv)
	end
	if opts.svm then
		if type(sv96_market_to_real) ~= 'function' then
			error('svm not supported')
		end
		set_sv96(sv96_market_to_real(opts.svm))
	end
	if opts.isomode then
		set_iso_mode(opts.isomode)
	end
	if opts.av then
		set_av96_direct(opts.av)
	end
	if opts.nd then
		set_nd_filter(opts.nd)
	end
	if opts.sd then
		if not opts.sdnoenable then
			focus:init()
			if not focus:enable_override(opts.sdprefmode) then
				error('focus override not available')
			end
			focus:set(opts.sd)
		else
			set_focus(opts.sd)
		end
	end
end
]],
},
--[[
create a dummy of the current image, used to prevent remoteshoot from crashing on play/shutdown
]]
{
	name='rlib_shoot_filedummy',
	depend={'mkdir_m'},
	code=[[
function rlib_shoot_filedummy()
	local dir=get_image_dir()
	local status,err=mkdir_m(dir)
	if not status then
		return false,err
	end
	local exts = {}
	if type(get_canon_image_format) == 'function' then
		local fmt = get_canon_image_format()
		if bitand(fmt,1) == 1 then
			table.insert(exts,'JPG')
		end
		if bitand(fmt,2) == 2 then
			table.insert(exts,'CR2')
		end
	else
		table.insert(exts,'JPG')
	end

	for i,e in ipairs(exts) do
		local fn=string.format('%s/IMG_%04d.%s',dir,get_exp_count(),e)
		-- don't overwrite an actual file if it exists
		if not os.stat(fn) then
			local fh,err=io.open(fn,'wb')
			if not fh then
				return false,err
			end
			fh:close()
			os.utime(fn)
		end
	end
	return true
end
]],
},
{
	name='rlib_shoot',
	depend={'rlib_shoot_common'}, -- note require serialize_msgs if info
	code=[[
function rlib_shoot(opts)
	local rec,vid = get_mode()
	if not rec then
		return false,'not in rec mode'
	end

	rlib_shoot_init_exp(opts)

	local save_cfmt
	if opts.cfmt then
		if type(get_canon_image_format) ~= 'function' then
			return false,'CHDK build does not support Canon format control' 
		end
		if opts.cfmt ~= 1 and not get_canon_raw_support() then
			return false,'platform does not support Canon raw' 
		end
		save_cfmt = get_canon_image_format()
		set_canon_image_format(opts.cfmt)
	end

	local save_raw
	if opts.raw then
		save_raw=get_raw()
		set_raw(opts.raw)
	end
	local save_dng
	if opts.dng then
		save_dng=get_config_value(226)
		set_config_value(226,opts.dng)
	end
	shoot()
	local r
	if opts.info then
		local raw_state = get_raw() -- hack for 1.3 compat
		if type(raw_state) == 'number' then
			raw_state = (raw_state == 1)
		end
		r = {
			dir=get_image_dir(),
			exp=get_exp_count(),
			raw=raw_state,
		}
		if type(get_canon_image_format) == 'function' then
			r.canon_fmt = get_canon_image_format()
		else
			r.canon_fmt = 1 -- jpeg
		end
		r.canon_jpg = (bitand(r.canon_fmt,1) == 1)
		r.canon_raw = (bitand(r.canon_fmt,2) == 2)

		if r.canon_raw then
			-- CHDK raw exception for canon raw
			if (get_config_value(1251) == 1) then
				r.raw = false
			end
		end
		if r.raw then
			r.raw_dir_opt = get_config_value(35)
			r.raw_pfx = get_config_value(36)
			r.raw_ext = get_config_value(37)
			r.dng = (get_config_value(226) == 1)
			if r.dng then
				r.use_dng_ext = (get_config_value(234) == 1)
			end
		end
	else
		r=true
	end
	if save_raw ~= nil then
		set_raw(save_raw)
	end
	if save_dng then
		set_config_value(226,save_dng)
	end
	if save_cfmt then
		set_canon_image_format(save_cfmt)
	end
	return r
end
	]],
},
--[[
support for cli remote capture shoot command
initializes remote shoot settings
]]
{
	name='rs_shoot_init',
	depend={'serialize_msgs','drive_mode_info'},
	code=[[
function rs_init(opts)
	local rec,vid = get_mode()
	if not rec then
		return false,'not in rec mode'
	end
	if type(init_usb_capture) ~= 'function' then
		return false, 'usb capture not supported'
	end
	if opts.cont then
		if not rlib_get_drive_mode_info().is_cont then
			return false, 'not in continuous mode'
		end
		if opts.int and opts.int > 0 and type(hook_shoot) ~= 'table' then
			return false, 'cont with interval requires hook_shoot support'
		end
	end
	if opts.shots and opts.shots <= 0 then
		return false, 'invalid shot count'
	end
	if bitand(get_usb_capture_support(),opts.fformat) ~= opts.fformat then
		return false, 'unsupported format'
	end
	local saved_canon_fmt
	if type(get_canon_raw_support) == 'function' and get_canon_raw_support() then
		local canon_fmt
		if bitand(opts.fformat,9) == 9 then
			canon_fmt = 3
		elseif bitand(opts.fformat,8) == 8 then
			canon_fmt = 2
		else
			canon_fmt = 1
		end
		if canon_fmt ~= get_canon_image_format() then
			saved_canon_fmt = get_canon_image_format()
			if not set_canon_image_format(canon_fmt) then
				return false, 'unsupported canon format'
			end
		end
	end
	if not init_usb_capture(opts.fformat,opts.lstart,opts.lcount) then
		return false, 'init failed'
	end
	if opts.cap_timeout then
		set_usb_capture_timeout(opts.cap_timeout)
	end
	return {saved_canon_fmt = saved_canon_fmt}
end
]],
},
{
	name='rs_shoot',
	depend={'rlib_shoot_common','rlib_shoot_filedummy'},
-- TODO should use shoot hook count for chdk 1.3, exp count may have issues in some ports
	code=[[
function rs_do_filedummy(opts)
	if not opts.filedummy then
		return
	end
	rlib_shoot_filedummy()
end
function rs_shoot_full(opts)
	local shot=0
	local m
	repeat
		local tnext=get_tick_count() + opts.int
		shoot()
		rs_do_filedummy(opts)
		shot = shot + 1
		if shot >= opts.shots then
			return
		end
		local tsleep=tnext - get_tick_count()
		if tsleep < 0 then
			tsleep = 0
		end
		m=read_usb_msg(tsleep)
	until m == 'quit'
end
function rs_shoot_multi_init()
	local state={
		last_exp_count = get_exp_count(),
		shots = 0,
	}
	press('shoot_half')
	repeat
		m=read_usb_msg(10)
	until get_shooting() or m == 'stop'
	if m == 'stop' then
		release('shoot_half')
		return false
	end
	sleep(20)
	return state
end

function rs_shoot_multi_wait(state,opts)
	local t0 = get_tick_count()
	while true do
		if state.wait_callback then
			if not state:wait_callback(opts) then
				return false
			end
		end
		m=read_usb_msg(10)
		if m == 'quit' then
			return false
		end
		local exp_count = get_exp_count()
		if state.last_exp_count ~= exp_count then
			state.shots = state.shots + 1
			state.last_exp_count = exp_count
			return true
		end
		if get_tick_count() - t0 > opts.exp_count_timeout then
			return false
		end
		if type(get_usb_capture_target) == 'function' and get_usb_capture_target() == 0 then
			return false
		end
	end
end

function rs_shoot_wait_hook(opts)
	local t0=get_tick_count()
	repeat
		if read_usb_msg(10) == 'quit' then
			return false
		end
		if get_tick_count() - t0 > opts.exp_count_timeout then
			return false
		end
	until hook_shoot.is_ready()
	return true
end

function rs_shoot_cont_hook(opts)
	hook_shoot.set(opts.shoot_hook_timeout)
	local state = rs_shoot_multi_init()
	if not state then
		return
	end
	local last_shot_tick
	press('shoot_full')
	repeat
		if not rs_shoot_wait_hook(opts) then
			break
		end
		-- if final shot, release immediately after hook to prevent extra shots
		if state.shots == opts.shots - 1 then
			release'shoot_full'
		end
		if last_shot_tick then
			local tsleep = last_shot_tick + opts.int - get_tick_count()
			if tsleep > 0 then
				if read_usb_msg(tsleep) == 'quit' then
					break
				end
			end
		end
		last_shot_tick = get_tick_count()
		hook_shoot.continue()
		if not rs_shoot_multi_wait(state,opts) then
			break
		end
		rs_do_filedummy(opts)
	until state.shots >= opts.shots
	hook_shoot.set(0)
	release('shoot_full')
end

function rs_shoot_cont(opts)
	local state = rs_shoot_multi_init()
	if not state then
		return
	end
	-- if shoot hooks available, release when hooked reached to avoid extra shots
	if type(hook_shoot) == 'table' then
		state.hook_shoot_count = hook_shoot.count()
		state.wait_callback = function(state,opts)
			local c = hook_shoot.count()
			if state.hook_shoot_count ~= c then
				if state.shots >= opts.shots - 1 then
					release('shoot_full')
				end
				state.hook_shoot_count = c
			end
			return true
		end
	end

	press('shoot_full')
	repeat
		if not rs_shoot_multi_wait(state,opts) then
			break
		end
		rs_do_filedummy(opts)
	until state.shots >= opts.shots
	release('shoot_full')
end

function rs_shoot_quick(opts)
	local state = rs_shoot_multi_init()
	if not state then
		return
	end
	-- if shoot hooks available, release when hooked reached to avoid extra shots
	if type(hook_shoot) == 'table' then
		state.wait_callback = function(state,opts)
			local c = hook_shoot.count()
			if state.hook_shoot_count ~= c then
				release('shoot_full_only')
				state.hook_shoot_count = c
			end
			return true
		end
	end
	while true do
		local t_next=get_tick_count() + opts.int
		if type(hook_shoot) == 'table' then
			state.hook_shoot_count = hook_shoot.count()
		end
		press('shoot_full_only')
		local status = rs_shoot_multi_wait(state,opts)
		release('shoot_full_only')
		rs_do_filedummy(opts)
		if state.shots >= opts.shots or not status then
			break
		end
		local tsleep=t_next - get_tick_count()
		if tsleep > 0 then
			if read_usb_msg(tsleep) == 'quit' then
				break
			end
		end
	end
	release('shoot_half')
end

function rs_shoot(opts)
	if not opts.int then
		opts.int=0
	end
	if not opts.shots then
		opts.shots=1
	end
	if not opts.exp_count_timeout then
		opts.exp_count_timeout = 5000
	end
	if not opts.shoot_hook_timeout then
		opts.shoot_hook_timeout=10000
	end
	if opts.shoot_hook_timeout <= opts.int then
		opts.shoot_hook_timeout=opts.int + 100
	end

	rlib_shoot_init_exp(opts)
	if opts.cont then
		if opts.int > 0 then
			rs_shoot_cont_hook(opts)
		else
			rs_shoot_cont(opts)
		end
	elseif opts.quick then
		rs_shoot_quick(opts)
	else
		rs_shoot_full(opts)
	end
end
]],
},
--[[
remote shoot cleanup - wait for get_shooting() to go false,
clear capture flags, restore any saved settings
]]
{
	name='rs_shoot_cleanup',
	code=[[
function rs_cleanup(opts)
	if not opts.nowait then
		local i = 0
		while get_shooting() and i < 200 do
			sleep(10)
			i = i+1
		end
	end
	init_usb_capture(0)
	if opts and opts.saved_canon_fmt then
		set_canon_image_format(opts.saved_canon_fmt)
	end
end
	]],
},
--[[
search memory for an aligned 32 bit word
mem_search_word{
	start:number
	last:number
	count:number
	val:number
	limit:number
}
]]
{
	name='mem_search_word',
	depend={'msg_batcher'},
	code=[[
function mem_search_word(opts)
	if type(opts) ~= 'table' then
		error('missing opts')
	end
	local _peek = peek
	local start = opts.start
	local last 
	if opts.count then
		last = start + (opts.count-1)*4
	else
		last = opts.last
	end
	local val = opts.val
	local limit = opts.limit
	if not start or not last or last < start or not val then
		error('bad opts')
	end
	local matches=0
	set_yield(-1,100)
	local b=msg_batcher()
	for i=start,last,4 do
		if _peek(i) == val then
			if not b:write(i) then
				error('write failed')
			end
			if limit then
				matches = matches+1
				if matches >= limit then
					break
				end
			end
		end
	end
	b:flush()
end
]]
},
--[[
a simple long lived script for interactive testing
example
!return con:exec('msg_shell:run()',{libs='msg_shell'})
putm exec message="hello world"
putm exec print(message)
]]
{
	name='msg_shell',
	code=[[
msg_shell={}
msg_shell.done=false
msg_shell.sleep=10
msg_shell.read_msg_timeout=10000
msg_shell.cmds={
	quit=function(msg)
		msg_shell.done=true
	end,
	echo=function(msg)
		if write_usb_msg(msg) then
			print("ok")
		else 
			print("fail")
		end
	end,
	exec=function(msg)
		local f,err=loadstring(string.sub(msg,5));
		if f then 
			local r={f()} -- pcall would be safer but anything that yields will fail
			for i, v in ipairs(r) do
				write_usb_msg(v)
			end
		else
			write_usb_msg(err)
			print("loadstring:"..err)
		end
	end,
	pcall=function(msg)
		local f,err=loadstring(string.sub(msg,6));
		if f then 
			local r={pcall(f)}
			for i, v in ipairs(r) do
				write_usb_msg(v)
			end
		else
			write_usb_msg(err)
			print("loadstring:"..err)
		end
	end,
}
msg_shell.idle = function()
	sleep(msg_shell.sleep)
end
msg_shell.run=function(self)
	repeat 
		local msg=read_usb_msg(self.read_msg_timeout)
		if msg then
			local cmd = string.match(msg,'^%w+')
			if type(self.cmds[cmd]) == 'function' then
				self.cmds[cmd](msg)
			elseif type(self.default_cmd) == 'function' then
				self.default_cmd(msg)
			elseif cmd then
				print('undefined command: '..tostring(cmd))
			else
				print('unexpected message: '..tostring(msg))
			end
		else
			self.idle()
		end
	until self.done
end
]],
},
}
return rlibs
