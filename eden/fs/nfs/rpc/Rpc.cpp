/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

#include "eden/fs/nfs/rpc/Rpc.h"

#include <folly/io/Cursor.h>

namespace facebook::eden {

EDEN_XDR_SERDE_IMPL(opaque_auth, flavor, body);
EDEN_XDR_SERDE_IMPL(mismatch_info, low, high);
EDEN_XDR_SERDE_IMPL(rpc_msg_call, xid, mtype, cbody);
EDEN_XDR_SERDE_IMPL(call_body, rpcvers, prog, vers, proc, cred, verf);
EDEN_XDR_SERDE_IMPL(rpc_msg_reply, xid, mtype, rbody);
EDEN_XDR_SERDE_IMPL(accepted_reply, verf, stat);
EDEN_XDR_SERDE_IMPL(authsys_parms, stamp, machinename, uid, gid, gids);

void serializeReply(
    folly::io::QueueAppender& ser,
    accept_stat status,
    uint32_t xid) {
  rpc_msg_reply reply{
      xid,
      msg_type::REPLY,
      reply_body{{
          reply_stat::MSG_ACCEPTED,
          accepted_reply{
              opaque_auth{
                  auth_flavor::AUTH_NONE,
                  {},
              },
              status,
          },
      }},
  };
  XdrTrait<rpc_msg_reply>::serialize(ser, reply);
}

std::optional<RpcCallPeek> peekRpcCallHeader(const folly::IOBuf& buf) {
  if (buf.computeChainDataLength() < kMinRpcCallSize) {
    return std::nullopt;
  }
  folly::io::Cursor cursor(&buf);
  cursor.skip(4); // fragment header
  auto xid = cursor.readBE<uint32_t>();
  auto msgType = cursor.readBE<uint32_t>();
  auto rpcvers = cursor.readBE<uint32_t>();
  // TODO: prog and vers are not validated here. The fast-path will reply
  // SUCCESS (null) or PROC_UNAVAIL (unimplemented) regardless of program
  // number, which is technically an RFC 5531 violation. In practice, the
  // NFS kernel client never sends the wrong program on a dedicated socket.
  cursor.skip(8);
  auto proc = cursor.readBE<uint32_t>();

  if (msgType != static_cast<uint32_t>(msg_type::CALL) ||
      rpcvers != kRPCVersion) {
    return std::nullopt;
  }
  return RpcCallPeek{xid, proc};
}

} // namespace facebook::eden
