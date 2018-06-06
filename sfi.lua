local lib14a = require('read14a')
local cmds = require('commands')
local bit32 = require('bit32')

local READ_RECORD = "00B2"

local function hex_dump(buf)
    for i=1,math.ceil(#buf/16) * 16 do
        if (i-1) % 16 == 0 then io.write(string.format('%08X  ', i-1)) end
        io.write( i > #buf and '   ' or string.format('%02X ', buf:byte(i)) )
        if i %  8 == 0 then io.write(' ') end
        if i % 16 == 0 then io.write( buf:sub(i-16+1, i):gsub('%c','.'), '\n' ) end
    end
end

local function fromhex(str)
    return (str:gsub('..', function (cc)
        return string.char(tonumber(cc, 16))
    end))
end

local function apdu_parse(result)
    local r = Command.parse(result)
    local total_len = r.arg1*2 - 4
    local data_len = total_len - 4

    local data = r.data:sub(1, data_len)
    local sw = r.data:sub(data_len + 1, data_len + 4)
    return data, sw
end

local function send_apdu(header, data, le)
    local command, flags, result, err
    flags = lib14a.ISO14A_COMMAND.ISO14A_APDU
    flags = flags + lib14a.ISO14A_COMMAND.ISO14A_NO_DISCONNECT

    apdu_data = ("%s%02X%s%02X"):format(header, #data/2, data, le)
    --print("Send APDU: ", apdu_data)

    command = Command:new{
        cmd = cmds.CMD_READER_ISO_14443a,
        arg1 = flags,
        arg2 = #apdu_data/2,
        data = apdu_data
    }

    result, err = lib14a.sendToDevice(command, false)
    --hex_dump(result:sub(1, 0x100))

    if not err then
        local response, sw = apdu_parse(result)
        return response, sw, nil
    end

    return nil, nil, err
end

local function connect()
    info, err = lib14a.read14443a(true, false)
    return info, err
end

local function read_record(sfi, record)
    p1 = record
    p2 = bit32.lshift(sfi, 3) + 4
    apdu = ("%s%02X%02X"):format(READ_RECORD, p1, p2)
    return send_apdu(apdu, "", 0)
end

local function brute()
    for sfi=1,31 do
        for record=1,256 do
            local res, sw = read_record(sfi, record)
            if sw == "9000" then
                print(("SFI: %i RECORD: %i, LEN: %i\nDATA: %s"):format(sfi, record, #res, res))
                hex_dump(fromhex(res))
            end
        end
        print(("SFI %i/31"):format(sfi))
    end
end

local function main()
    info, err = connect()

    if not err then
        print(("Connected to card, uid = %s"):format(info.uid))
    end
    brute()
end

main()
