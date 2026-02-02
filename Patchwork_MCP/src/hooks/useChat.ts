import { useState, useCallback, useMemo } from "react";
import { Id } from "../../convex/_generated/dataModel";
import { useQuery, useMutation, usePaginatedQuery } from "convex/react";
import { api } from "../../convex/_generated/api";

export interface Message {
  _id: Id<"messages">;
  conversationId: Id<"conversations">;
  senderId: Id<"users">;
  type: "text" | "proposal" | "system";
  content: string;
  proposalId?: Id<"proposals">;
  proposal?: Proposal | null;
  attachments?: Id<"_storage">[];
  readAt?: number;
  createdAt: number;
  updatedAt: number;
}

export interface Proposal {
  _id: Id<"proposals">;
  conversationId: Id<"conversations">;
  senderId: Id<"users">;
  receiverId: Id<"users">;
  jobRequestId?: Id<"jobRequests">;
  rate: number;
  rateType: "hourly" | "flat";
  startDateTime: string;
  notes?: string;
  status: "pending" | "accepted" | "declined" | "countered" | "expired";
  previousProposalId?: Id<"proposals">;
  counterProposalId?: Id<"proposals">;
  createdAt: number;
  updatedAt: number;
  expiresAt?: number;
}

/**
 * Conversation type matching Convex schema
 */
export interface Conversation {
  _id: Id<"conversations">;
  seekerId: Id<"users">;
  taskerId: Id<"users">;
  jobRequestId?: Id<"jobRequests">;
  jobId?: Id<"jobs">;
  lastMessageAt: number;
  lastMessageId?: Id<"messages">;
  lastMessagePreview?: string;
  lastMessageSenderId?: Id<"users">;
  seekerUnreadCount: number;
  taskerUnreadCount: number;
  seekerLastReadAt?: number;
  taskerLastReadAt?: number;
  createdAt: number;
  updatedAt: number;
}

/**
 * Return type for useChat hook
 */
export interface UseChatReturn {
  messages: Message[];
  isLoading: boolean;
  hasMoreMessages: boolean;
  sendMessage: (content: string, attachments?: Id<"_storage">[]) => Promise<void>;
  sendProposal: (
    rate: number,
    rateType: "hourly" | "flat",
    startDateTime: string,
    notes?: string
  ) => Promise<void>;
  acceptProposal: (proposalId: Id<"proposals">) => Promise<void>;
  declineProposal: (proposalId: Id<"proposals">) => Promise<void>;
  counterProposal: (
    proposalId: Id<"proposals">,
    rate: number,
    rateType: "hourly" | "flat",
    startDateTime: string,
    notes?: string
  ) => Promise<void>;
  loadMoreMessages: () => void;
  currentUser: any | null;
  completeJob: (jobId: Id<"jobs">) => Promise<void>;
  createReview: (jobId: Id<"jobs">, rating: number, text: string) => Promise<void>;
  conversation: Conversation | null | undefined;
  job: any | null | undefined;
}

export function useChat(conversationId: Id<"conversations">): UseChatReturn {
  const currentUser = useQuery(api.users.getCurrentUser);
  const conversation = useQuery(api.conversations.getConversation, { conversationId });
  const job = useQuery(api.jobs.getJob, conversation?.jobId ? { jobId: conversation.jobId } : "skip");
  
  const { results, status, loadMore } = usePaginatedQuery(
    api.messages.listMessages,
    { conversationId },
    { initialNumItems: 25 }
  );

  const sendMessageMutation = useMutation(api.messages.sendMessage);
  const sendProposalMutation = useMutation(api.proposals.sendProposal);
  const acceptProposalMutation = useMutation(api.proposals.acceptProposal);
  const declineProposalMutation = useMutation(api.proposals.declineProposal);
  const counterProposalMutation = useMutation(api.proposals.counterProposal);
  const completeJobMutation = useMutation(api.jobs.completeJob);
  const createReviewMutation = useMutation(api.reviews.createReview);

  const messages = useMemo(() => {
    return [...(results || [])].reverse() as Message[];
  }, [results]);

  const isLoading = status === "LoadingFirstPage";
  const hasMoreMessages = status === "CanLoadMore";

  const sendMessage = useCallback(async (
    content: string,
    attachments?: Id<"_storage">[]
  ) => {
    await sendMessageMutation({
      conversationId,
      content,
      attachments,
    });
  }, [conversationId, sendMessageMutation]);

  const sendProposal = useCallback(async (
    rate: number,
    rateType: "hourly" | "flat",
    startDateTime: string,
    notes?: string
  ) => {
    await sendProposalMutation({
      conversationId,
      rate,
      rateType,
      startDateTime,
      notes,
    });
  }, [conversationId, sendProposalMutation]);

  const acceptProposal = useCallback(async (proposalId: Id<"proposals">) => {
    await acceptProposalMutation({ proposalId });
  }, [acceptProposalMutation]);

  const declineProposal = useCallback(async (proposalId: Id<"proposals">) => {
    await declineProposalMutation({ proposalId });
  }, [declineProposalMutation]);

  const counterProposal = useCallback(async (
    proposalId: Id<"proposals">,
    rate: number,
    rateType: "hourly" | "flat",
    startDateTime: string,
    notes?: string
  ) => {
    await counterProposalMutation({
      proposalId,
      rate,
      rateType,
      startDateTime,
      notes,
    });
  }, [counterProposalMutation]);

  const completeJob = useCallback(async (jobId: Id<"jobs">) => {
    await completeJobMutation({ jobId });
  }, [completeJobMutation]);

  const createReview = useCallback(async (jobId: Id<"jobs">, rating: number, text: string) => {
    await createReviewMutation({ jobId, rating, text });
  }, [createReviewMutation]);

  const loadMoreMessages = useCallback(() => {
    if (status === "CanLoadMore") {
      loadMore(25);
    }
  }, [status, loadMore]);

  return {
    messages,
    isLoading,
    hasMoreMessages,
    sendMessage,
    sendProposal,
    acceptProposal,
    declineProposal,
    counterProposal,
    loadMoreMessages,
    currentUser,
    completeJob,
    createReview,
    conversation,
    job,
  };
}
