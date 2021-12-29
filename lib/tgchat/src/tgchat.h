// tgchat.h
//
// Copyright (c) 2020-2021 Kristofer Berggren
// All rights reserved.
//
// nchat is distributed under the MIT license, see LICENSE for details.

#pragma once

#include <condition_variable>
#include <deque>
#include <set>
#include <thread>

#include <td/telegram/Client.h>

#include "config.h"
#include "protocol.h"

class TgChat : public Protocol
{
public:
  TgChat();
  virtual ~TgChat();
  std::string GetProfileId() const;
  bool HasFeature(ProtocolFeature p_ProtocolFeature) const;
  void SetProperty(ProtocolProperty p_Property, const std::string& p_Value);

  bool SetupProfile(const std::string& p_ProfilesDir, std::string& p_ProfileId);
  bool LoadProfile(const std::string& p_ProfilesDir, const std::string& p_ProfileId);
  bool CloseProfile();

  bool Login();
  bool Logout();

  void Process();

  void SendRequest(std::shared_ptr<RequestMessage> p_RequestMessage);
  void SetMessageHandler(const std::function<void(std::shared_ptr<ServiceMessage>)>& p_MessageHandler);

private:
  enum ChatType
  {
    ChatPrivate = 0,
    ChatBasicGroup,
    ChatSuperGroup,
    ChatSuperGroupChannel,
    ChatSecret,
  };

private:
  void CallMessageHandler(std::shared_ptr<ServiceMessage> p_ServiceMessage);
  void PerformRequest(std::shared_ptr<RequestMessage> p_RequestMessage);

  using Object = td::td_api::object_ptr<td::td_api::Object>;
  void Init();
  void Cleanup();
  void ProcessService();
  void ProcessResponse(td::Client::Response response);
  void ProcessUpdate(td::td_api::object_ptr<td::td_api::Object> update);
  std::function<void(TgChat::Object)> CreateAuthQueryHandler();
  void OnAuthStateUpdate();
  void SendQuery(td::td_api::object_ptr<td::td_api::Function> f, std::function<void(Object)> handler);
  void CheckAuthError(Object object);
  void CreateChat(Object p_Object);
  std::string GetRandomString(size_t p_Len);
  std::uint64_t GetNextQueryId();
  std::int64_t GetSenderId(const td::td_api::message& p_TdMessage);
  std::string GetText(td::td_api::object_ptr<td::td_api::formattedText>&& p_FormattedText);
  void TdMessageContentConvert(td::td_api::MessageContent& p_TdMessageContent,
                               std::string& p_Text, std::string& p_FileInfo);
  void TdMessageConvert(td::td_api::message& p_TdMessage, ChatMessage& p_ChatMessage);
  void DownloadFile(std::string p_ChatId, std::string p_MsgId, std::string p_FileId,
                    DownloadFileAction p_DownloadFileAction);
  void RequestSponsoredMessagesIfNeeded();
  void GetSponsoredMessages(const std::string& p_ChatId);
  void ViewSponsoredMessage(const std::string& p_ChatId, const std::string& p_MsgId);
  bool IsSponsoredMessageId(const std::string& p_MsgId);

private:
  std::string m_ProfileId = "Telegram";
  std::string m_ProfileDir;
  std::function<void(std::shared_ptr<ServiceMessage>)> m_MessageHandler;

  bool m_Running = false;
  std::thread m_Thread;
  std::deque<std::shared_ptr<RequestMessage>> m_RequestsQueue;
  std::mutex m_ProcessMutex;
  std::condition_variable m_ProcessCondVar;

  std::thread m_ServiceThread;
  std::string m_SetupPhoneNumber;
  Config m_Config;
  std::unique_ptr<td::Client> m_Client;
  std::map<std::uint64_t, std::function<void(Object)>> m_Handlers;
  td::td_api::object_ptr<td::td_api::AuthorizationState> m_AuthorizationState;
  bool m_IsSetup = false;
  bool m_Authorized = false;
  bool m_WasAuthorized = false;
  std::int64_t m_SelfUserId = 0;
  std::uint64_t m_AuthQueryId = 0;
  std::uint64_t m_CurrentQueryId = 0;
  std::map<int64_t, int64_t> m_LastReadInboxMessage;
  std::map<int64_t, int64_t> m_LastReadOutboxMessage;
  std::map<int64_t, std::set<int64_t>> m_UnreadOutboxMessages;
  std::map<int64_t, ContactInfo> m_ContactInfos;
  std::map<int64_t, ChatType> m_ChatTypes;
  int64_t m_CurrentChat = 0;
  const char m_SponsoredMessageMsgIdPrefix = '+';
  std::map<std::string, std::set<std::string>> m_SponsoredMessageIds;
  bool m_AttachmentPrefetchAll = true;
};
