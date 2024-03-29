--[[
 Copyright (C) 2016-2020 <reyalp (at) gmail dot com>

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License version 2 as
  published by the Free Software Foundation.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  with chdkptp. If not, see <http://www.gnu.org/licenses/>.

various dev utils as cli commands
usage
!require'extras/devutil':init_cli()
use help for information about individual commands
--]]
local m={}
local proptools=require'extras/proptools'
local paramtools=require'extras/paramtools'
local vxromlog=require'extras/vxromlog'

m.stop_uart_log = function()
	if not m.logname then
		errlib.throw{etype='bad_arg',msg='log not started'}
	end
	con:execwait([[
require'uartr'.stop()
]])
end

m.resume_uart_log = function()
	if not m.logname then
		errlib.throw{etype='bad_arg',msg='log not started'}
	end
	con:execwait(string.format([[
require'uartr'.start('%s',false,0x%x)
]],m.logname,m.logsize+512))
end

m.init_cli = function()
	cli:add_commands{
	{
		names={'dlstart'},
		help='start uart log w/large log buffers',
		arghelp="[options] [file]",
		args=cli.argparser.create{
			csize=0x6000,
			clevel=0x20,
			a=false,
		},
		help_detail=[[
 [file] name for log file, default A/dbg.log
 options
  -csize=<n> camera log buffer size, default 0x6000
  -clevel=<n> camera log level, messages with matching bits set are logged. default 0x20
  -a  append to existing log
 requires native calls enabled, camera with uart log support (all DryOS)
]],
		func=function(self,args)
			local logname=args[1]
			if not logname then
				logname='dbg.log'
			end
			opts = {
				logname=fsutil.make_camera_path(logname),
				overwrite=(args.a==false),
				logsize=tonumber(args.csize)+512,
				clevel=tonumber(args.clevel),
				csize=tonumber(args.csize),
			}
			con:execwait('opts='..serialize(opts)..[[

call_event_proc('StopCameraLog')
sleep(200)
call_event_proc('StartCameraLog',opts.clevel,opts.csize)
sleep(100)
require'uartr'.start(opts.logname,opts.overwrite,opts.logsize)
sleep(100)
call_event_proc('Printf',
	'%s dlstart CameraLog 0x%x,0x%x Uart "%s",%s,0x%x\n',
	os.date('%Y%m%d %H:%M:%S'),
	opts.clevel,opts.csize,
	opts.logname,tostring(opts.overwrite),opts.logsize
	)
]])
			m.logname=logname
			m.logsize=args.csize
			return true,'log started: '..m.logname
		end
	},
	{
		names={'dlgetcam'},
		help='print camera log on uart, download uart log',
		arghelp="[local]",
		args=cli.argparser.create{},
		help_detail=[[
 [local] name to download log to, default same as uart log
 log must have been started with dlstart
]],
		func=function(self,args)
			if not m.logname then
				return false,'log not started'
			end
			con:execwait([[
call_event_proc('Printf','%s dlgetcam\n',os.date('%Y%m%d %H:%M:%S'))
call_event_proc('ShowCameraLog')
call_event_proc('Printf','%s dlgetcam end\n',os.date('%Y%m%d %H:%M:%S'))
]])
			sys.sleep(1000) -- 500 was sometimes too short
			local dlcmd='download '..m.logname
			if args[1] then
				dlcmd = dlcmd..' '..args[1]
			end
			return cli:execute(dlcmd)
		end
	},
	{
		names={'dlget'},
		help='download uart log',
		arghelp="[local]",
		args=cli.argparser.create{},
		help_detail=[[
 [local] name to download log to, default same as uart log
 log must have been started with startlog
]],

		func=function(self,args)
			if not m.logname then
				return false,'log not started'
			end
			local dlcmd='download '..m.logname
			if args[1] then
				dlcmd = dlcmd..' '..args[1]
			end
			return cli:execute(dlcmd)
		end
	},
	{
		names={'dlstop'},
		help='stop uart log',
		func=function(self,args)
			m.stop_uart_log()
			return true
		end
	},
	{
		names={'dlresume'},
		help='resume uart log',
		func=function(self,args)
			m.resume_uart_log()
			return true
		end
	},
	{
		names={'dpget'},
		help='get range of propcase values',
		arghelp="[options]",
		args=cli.argparser.create{
			s=0,
			e=999,
			c=false,
		},
		help_detail=[[
 options:
  -s=<number> min prop id, default 0
  -e=<number> max prop id, default 999
  -c=<code> lua code to execute before getting props
]],

		func=function(self,args)
			args.e=tonumber(args.e)
			args.s=tonumber(args.s)
			if args.e < args.s then
				return false,'invalid range'
			end
			m.psnap=proptools.get(args.s, args.e + 1 - args.s,args.c)
			return true
		end
	},
	{
		names={'dpsave'},
		help='save propcase values obtained with dpget',
		arghelp="[file]",
		args=cli.argparser.create{ },
		help_detail=[[
 [file] output file
]],

		func=function(self,args)
			if not m.psnap then
				return false,'no saved props'
			end
			if not args[1] then
				return false,'missing filename'
			end
			proptools.write(m.psnap,args[1])
			return true,'saved '..args[1]
		end
	},
	{
		names={'dpcmp'},
		help='compare current propcase values with last dpget',
		arghelp="[options]",
		args=cli.argparser.create{
			c=false,
		},
		help_detail=[[
 options:
  -c=<code> lua code to execute before getting props
]],
		func=function(self,args)
			if not m.psnap then
				return false,'no saved props'
			end
			proptools.comp(m.psnap,proptools.get(m.psnap._min, m.psnap._max - m.psnap._min,args.c))
			return true
		end
	},
	{
		names={'dfpget'},
		help='get range of flash param values',
		arghelp="[options]",
		args=cli.argparser.create{
			s=0,
			e=false,
			c=false,
		},
		help_detail=[[
 options:
  -s=<number> min param id, default 0
  -e=<number> max param id, default flash_params_count - 1
  -c=<code> lua code to execute before getting
]],

		func=function(self,args)
			args.s=tonumber(args.s)
			local count
			if args.e then
				args.e=tonumber(args.e)
				if args.e < args.s then
					return false,'invalid range'
				end
				count = args.e + 1 - args.s
			end
			m.fpsnap=paramtools.get(args.s,count,args.c)
			return true
		end
	},
	{
		names={'dfpsave'},
		help='save flash param values obtained with dfpget',
		arghelp="[file]",
		args=cli.argparser.create{ },
		help_detail=[[
 [file] output file
]],

		func=function(self,args)
			if not m.fpsnap then
				return false,'no saved params'
			end
			if not args[1] then
				return false,'missing filename'
			end
			paramtools.write(m.fpsnap,args[1])
			return true,'saved '..args[1]
		end
	},
	{
		names={'dfpcmp'},
		help='compare current param values with last dfpget',
		arghelp="[options]",
		args=cli.argparser.create{
			c=false,
		},
		help_detail=[[
 options:
  -c=<code> lua code to execute before getting params
]],
		func=function(self,args)
			if not m.fpsnap then
				return false,'no saved props'
			end
			paramtools.comp(m.fpsnap,paramtools.get(m.fpsnap._min, m.fpsnap._max - m.fpsnap._min,args.c))
			return true
		end
	},
	{
		names={'dsearch32'},
		help='search memory for specified 32 bit value',
		arghelp="[-l=<n>] [-c=<n>] [-cb=<n>] [-ca=<n>] <start> <end> <val>",
		args=cli.argparser.create{
			l=false,
			c=false,
			cb=false,
			ca=false,
		},
		help_detail=[[
 <start> start address
 <end>   end address
 <val>   value to find
 options
  -l=<n> stop after n matches 
  -c=<n> show N words before and after
  -cb=<n> show N words before match
  -ca=<n> show N words after match
]],
		func=function(self,args)
			local start=tonumber(args[1])
			local last=tonumber(args[2])
			local val=tonumber(args[3])
			if not start then
				return false, 'missing start address'
			end
			if not last then
				return false, 'missing end address'
			end
			if not val then
				return false, 'missing value'
			end
			local do_ctx
			local ctx_before = 0
			local ctx_after = 0
			if args.c then
				do_ctx=true
				ctx_before = tonumber(args.c)
				ctx_after = tonumber(args.c)
			end
			if args.cb then
				do_ctx=true
				ctx_before = tonumber(args.cb)
			end
			if args.ca then
				do_ctx=true
				ctx_after = tonumber(args.ca)
			end

			printf("search 0x%08x-0x%08x 0x%08x\n",start,last,val)
			local t={}
			-- TODO should have ability to save results since it's slow
			con:execwait(string.format([[
mem_search_word{start=0x%x, last=0x%x, val=0x%x, limit=%s}
]],start,last,val,tostring(args.l)),{libs='mem_search_word',msgs=chdku.msg_unbatcher(t)})
			for i,v in ipairs(t) do
				local adr=bit32.band(v,0xFFFFFFFF)
				if do_ctx then
					if adr > ctx_before then
						adr = adr - 4*ctx_before
					else
						adr = 0
					end
					local count=ctx_before + ctx_after + 1
					cli:print_status(cli:execute(('rmem -i32 0x%08x %d'):format(adr,count)))
				else
					printf("0x%08x\n",adr) 
				end
			end
			return true
		end
	},
	{
		names={'dromlog'},
		help='get camera romlog',
		arghelp="[options] [dest]",
		args=cli.argparser.create{
			p=false,
			pa=false,
			nodecode=false,
		},
		help_detail=[[
 [dest] path/name for downloaded file, default ROMLOG.LOG
 options
   -nodecode do not decode vxworks romlog
   -p        print error, registers, stack
   -pa       print full log

 GK.LOG / RomLogErr.txt will be prefixed with dst name if present
 Binary vxworks log will have .bin appended if decoding enabled

 requires native calls enabled
 existing ROMLOG.LOG, GK.LOG and RomLogErr.txt files on cam will be removed
]],
		func=function(self,args)
			local dst=args[1]
			local gkdst
			local errdst
			if dst then
				-- make GK log name based on dest 
				local dstbase=fsutil.split_ext(dst)
				gkdst=dstbase..'-GK.LOG'
				errdst=dstbase..'-Err.LOG'
			else
				dst='ROMLOG.LOG'
				gkdst='GK.LOG'
				errdst='RomLogErr.txt'
			end
			local r = con:execwait([[
LOG_NAME="A/ROMLOG.LOG"
GKLOG_NAME="A/GK.LOG"
ERR_NAME="A/RomLogErr.txt"

if call_event_proc("SystemEventInit") == -1 then
    if call_event_proc("System.Create") == -1 then
        error("ERROR: SystemEventInit and System.Create failed")
    end
end
if os.stat(LOG_NAME) then
	os.remove(LOG_NAME)
end
if os.stat(GKLOG_NAME) then
	os.remove(GKLOG_NAME)
end
if os.stat(ERR_NAME) then
	os.remove(ERR_NAME)
end

-- first arg: filename, NULL for ROMLOG.TXT (dryos) or ROMLOG (vxworks)
-- second arg: if 0, shutdown camera after writing log
-- note, on vxworks the exception code, registers and stack trace are binary
call_event_proc("GetLogToFile",LOG_NAME,1)
-- get OS for log decoding
camos=get_buildinfo().os
if os.stat(ERR_NAME) then
	return {status=false, logname=ERR_NAME, os=camos}
end

if not os.stat(LOG_NAME) then
    error('logfile %s does not exist',LOG_NAME)
end
if os.stat(GKLOG_NAME) then
	return {status=true, logname=LOG_NAME, gklogname=GKLOG_NAME, os=camos}
else
	return {status=true, logname=LOG_NAME, os=camos}
end
]])
			if not r.status then
				cli.infomsg("%s->%s\n",r.logname,errdst)
				con:download(r.logname,errdst)
				return false,string.format("ROMLOG failed, error %s\n",errdst)
			end
			local dldst = dst
			if r.os == 'vxworks' and not args.nodecode then
				dldst = dldst..'.bin'
			end
			cli.infomsg("%s->%s\n",r.logname,dldst)
			con:download(r.logname,dldst)
			local vxlog
			if r.os == 'vxworks' and not args.nodecode then
				cli.infomsg("decode vxworks %s->%s\n",dldst,dst)
				vxlog=vxromlog.load(dldst)
				local fh=fsutil.open_e(dst,'wb')
				vxlog:print_all(fh)
				fh:close()
			end
			if r.gklogname then
				cli.infomsg("%s->%s\n",r.gklogname,gkdst)
				con:download(r.gklogname,gkdst)
			end
			if args.pa then
				if vxlog then
					vxlog:print_all()
				else
					printf("%s",fsutil.readfile_e(dst,'b'))
				end
			elseif args.p then
				if vxlog then
					vxlog:print()
				else
					local fh=fsutil.open_e(dst,'rb')
					for l in fh:lines() do
						if l:match('^CameraConDump:') then
							break;
						end
						printf("%s\n",l)
					end
					fh:close();
				end
			end
			return true
		end
	},
	{
		names={'dscriptdisk'},
		help='make script disk',
		arghelp="",
		args=cli.argparser.none,
		help_detail=[[
Prepare card as Canon Basic script disk. Requires native calls
]],
		func=function(self,args)
			con:execwait([[
if call_event_proc("SystemEventInit") == -1 then
	if call_event_proc("System.Create") ~= 0 then
		error('System eventproc reg failed')
	end
end

f=io.open("A/SCRIPT.REQ","w")
if not f then
	error("file open failed")
end
f:write("for DC_scriptdisk")
f:close()

if call_event_proc("MakeScriptDisk",0) ~= 0 then
	error('MakeScriptDisk failed')
end

]])
			return true, 'Script disk initialized'
		end
	},
	{
		names={'dvxromlog'},
		help='decode VxWorks ROMLOG',
		arghelp="<infile> [outfile]",
		args=cli.argparser.create{
			all=false,
	 	},
		help_detail=[[
 <infile>  local path of VxWorks ROMLOG to decode
 [outfile] output file, default standard output
 options
  -all     include cameralog
]],
		func=function(self,args)
			local logname=args[1]
			local outfile=args[2]
			if not logname then
				error('missing log name')
			end
			local log=vxromlog.load(logname)
			local fh
			if outfile then
				fh=fsutil.open_e(outfile,'wb')
			end
			if args.all then
				log:print_all(fh)
			else
				log:print(fh)
			end
			if fh then
				fh:close()
			end
			return true
		end
	},
	{
		names={'dptpsendobj'},
		help='upload a file using standard PTP',
		arghelp="<src> <dst>",
		args=cli.argparser.create{
			ofmt=0xbf01,
	 	},
		help_detail=[[
 <src> local file to upload
 <dst> name to upload to.
 options
  -ofmt     object format code, default 0xbf01

NOTE:
Some cameras (Digic 2, VxWorks A540) crash if dst DOES NOT start with A/
Others (Digic 4, DryOS) crash if it DOES start with A/
Either crash is an assert in OpObjHdl.c

]],
		func=function(self,args)
			local src=args[1]
			local dst=args[2]
			if not src then
				return false,'missing src'
			end
			if not dst then
				return false,'missing dst'
			end
			local data=fsutil.readfile_e(src,'b')
			local ofmt=tonumber(args.ofmt)
			cli.infomsg("SendObjectInfo(Filename=%s,ObjectFormat=0x%x,ObjectCompressedSize=%d)\n", dst,ofmt,data:len())
			local objh = con:ptp_send_object_info({
				Filename=dst,
				ObjectFormat=ofmt,
				ObjectCompressedSize=data:len()
			})
			cli.infomsg("Received handle 0x%x, sending data\n",objh)
			con:ptp_send_object(data)
			return true
		end
	},
	{
		names={'dptplistobjs'},
		help='List objects PTP objects',
		arghelp="[options] [handle1] ...",
		args=cli.argparser.create{
			stid=0xFFFFFFFF,
			ofmt=0,
			assoc=0,
			h=false,
		},
		help_detail=[[
 [handle]   specify handles to list info for, default all
 options
  -stid     storage ID, default 0xFFFFFFFF (all)
  -ofmt     object format code, default 0 (any)
  -assoc    association, default 0 (any)
  -h		only list handles, do not query info

NOTE:
Listing all handles will probably cause the camera display to go black and make
switching to shooting mode impossible until USB is disconnected or the camera
is restarted

]],
		func=function(self,args)
			local oh
			if #args > 0 then
				oh={}
				for i,h in ipairs(args) do
					table.insert(oh,tonumber(h))
				end
			else
				oh=con:ptp_get_object_handles(args.stid,args.ofmt,args.assoc)
			end
			for i,h in ipairs(oh) do
				if args.h then
					printf('0x%x\n',h)
				else
					local oi = con:ptp_get_object_info(h)
					printf('0x%x:%s\n',h,util.serialize(oi,{pretty=true}))
				end
			end
			return true
		end
	},
	{
		names={'dptpstorageinfo'},
		help='List PTP storage info',
		arghelp="[storage id] | [-i]",
		args=cli.argparser.create{
			i=false
		},
		help_detail=[[
 [stoarge id]   list only information for a specific storage id. Default all

 options
  -i only list IDs without querying info

]],
		func=function(self,args)
			local sids
			if args[1] then
				sids={tonumber(args[1])}
			else	
				sids=con:ptp_get_storage_ids()
			end
			for i,sid in ipairs(sids) do 
				if args.i then
					printf('0x%x\n',sid)
				else
					si = con:ptp_get_storage_info(sid)
					printf('0x%x:%s\n',sid,util.serialize(si,{pretty=true}))
				end
			end
			return true
		end
	},

}
end

return m
