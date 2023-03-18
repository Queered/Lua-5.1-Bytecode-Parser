local function parseByteCode(bytecode)
   local header = {string.byte(bytecode, 1, 12)}

   if header[1] ~= 27 or header[2] ~= 76 or header[3] ~= 117 or header[4] ~= 97 then
      error("Invalid Lua bytecode format")
   end

   if header[5] ~= 5 or header[6] ~= 1 or header[7] ~= 4 or header[8] ~= 4 or header[9] ~= 4 then
      error("Unsupported Lua bytecode version")
   end

   local function getUint32(offset)
      local b1, b2, b3, b4 = string.byte(bytecode, offset, offset + 3)
      return b1 + b2 * 256 + b3 * 65536 + b4 * 16777216
   end

   local function getInt32(offset)
      local uint32 = getUint32(offset)
      if uint32 > 2147483647 then
         return uint32 - 4294967296
      end
      return uint32
   end

   local function getInstruction(offset)
      return string.byte(bytecode, offset) + string.byte(bytecode, offset + 1) * 256 + string.byte(bytecode, offset + 2) * 65536
   end

   local function parseFunctionInfo(offset)
      local functionInfo = {}

         functionInfo.source = getUint32(offset)
            offset = offset + 4

            functionInfo.lineDefined = getUint32(offset)
               offset = offset + 4

               functionInfo.lastLineDefined = getUint32(offset)
                  offset = offset + 4

                  functionInfo.numUpvalues = string.byte(bytecode, offset)
                     offset = offset + 1

                     functionInfo.numParams = string.byte(bytecode, offset)
                        offset = offset + 1

                        functionInfo.isVarArg = string.byte(bytecode, offset)
                           offset = offset + 1

                           functionInfo.maxStackSize = string.byte(bytecode, offset)
                              offset = offset + 1

                              functionInfo.code = {}
                                 local codeSize = getUint32(offset)
                                 offset = offset + 4

                                 for i = 1, codeSize do
                                    functionInfo.code[i] = getInstruction(offset)
                                       offset = offset + 4
                                    end

                                    functionInfo.constants = {}
                                       local numConstants = getUint32(offset)
                                       offset = offset + 4

                                       for i = 1, numConstants do
                                          local type = string.byte(bytecode, offset)
                                          offset = offset + 1

                                          if type == 1 then -- nil
                                             functionInfo.constants[i] = nil
                                             elseif type == 3 then -- boolean
                                                functionInfo.constants[i] = string.byte(bytecode, offset) ~= 0
                                                   offset = offset + 1
                                                elseif type == 4 then -- number
                                                   functionInfo.constants[i] = tonumber(string.sub(bytecode, offset, offset + 7))
                                                      offset = offset + 8
                                                   elseif type == 8 then -- string
                                                      local size = getUint32(offset)
                                                      offset = offset + 4
                                                      functionInfo.constants[i] = string.sub(bytecode, offset, offset + size - 1)
                                                         offset = offset + size
                                                      else
                                                         error("Invalid constant type " .. type)
                                                      end
                                                   end

                                                   functionInfo.upvalues = {}
                                                      local numUpvalues = getUint32(offset)
                                                      offset = offset + 4

                                                      for i = 1, numUpvalues do
                                                         local isLocal = string.byte(bytecode, offset)
                                                         offset = offset + 1

                                                         local index = string.byte(bytecode, offset)
                                                         offset = offset + 1

                                                         functionInfo.upvalues[i] = {isLocal = isLocal == 1, index = index}
                                                         end

                                                         functionInfo.functions = {}
                                                            local numFunctions = getUint32(offset)
                                                            offset = offset + 4

                                                            for i = 1, numFunctions do
                                                               local subFunctionOffset = offset
                                                               local subFunctionInfo = parseFunctionInfo(subFunctionOffset)
                                                               functionInfo.functions[i] = subFunctionInfo

                                                                  offset = subFunctionOffset + subFunctionInfo.size
                                                               end

                                                               functionInfo.size = offset - startOffset

                                                                  return functionInfo
                                                               end

                                                               return parseFunctionInfo(13)

