import { useState } from "react";
import { Id } from "../../convex/_generated/dataModel";

/**
 * Message type matching Convex schema
 */
export interface Message {
  _id: Id<"messages">;
  conversationId: Id<"conversations">;
  senderId: Id<"users">;
  type: "text" | "proposal" | "system";
  content: string;
  proposalId?: Id<"proposals">;
  attachments?: Id<"_storage">[];
  readAt?: number;
  createdAt: number;
  updatedAt: number;
}

/**
 * Proposal type matching Convex schema
 */
export interface Proposal {
  _id: Id<"proposals">;
  conversationId: Id<"conversations">;
  senderId: Id<"users">;
  receiverId: Id<"users">;
  jobRequestId?: Id<"jobRequests">;
  rate: number; // in cents
  rateType: "hourly" | "flat";
  startDateTime: string; // ISO datetime
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
  loadMoreMessages: () => Promise<void>;
}

/**
 * useChat hook - manages conversation state and messaging
 * 
 * Placeholder implementation - will be wired to Convex in Task 8
 * 
 * @param conversationId - The ID of the conversation
 * @returns UseChatReturn object with messages and action methods
 */
export function useChat(conversationId: Id<"conversations">): UseChatReturn {
  const [messages, setMessages] = useState<Message[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [hasMoreMessages, setHasMoreMessages] = useState(false);

  const sendMessage = async (
    content: string,
    attachments?: Id<"_storage">[]
  ): Promise<void> => {
    console.log("sendMessage placeholder:", {
      conversationId,
      content,
      attachments,
    });
    // TODO: Wire to Convex mutation in Task 8
  };

  const sendProposal = async (
    rate: number,
    rateType: "hourly" | "flat",
    startDateTime: string,
    notes?: string
  ): Promise<void> => {
    console.log("sendProposal placeholder:", {
      conversationId,
      rate,
      rateType,
      startDateTime,
      notes,
    });
    // TODO: Wire to Convex mutation in Task 8
  };

  const acceptProposal = async (proposalId: Id<"proposals">): Promise<void> => {
    console.log("acceptProposal placeholder:", {
      conversationId,
      proposalId,
    });
    // TODO: Wire to Convex mutation in Task 8
  };

  const declineProposal = async (proposalId: Id<"proposals">): Promise<void> => {
    console.log("declineProposal placeholder:", {
      conversationId,
      proposalId,
    });
    // TODO: Wire to Convex mutation in Task 8
  };

  const counterProposal = async (
    proposalId: Id<"proposals">,
    rate: number,
    rateType: "hourly" | "flat",
    startDateTime: string,
    notes?: string
  ): Promise<void> => {
    console.log("counterProposal placeholder:", {
      conversationId,
      proposalId,
      rate,
      rateType,
      startDateTime,
      notes,
    });
    // TODO: Wire to Convex mutation in Task 8
  };

  const loadMoreMessages = async (): Promise<void> => {
    console.log("loadMoreMessages placeholder:", {
      conversationId,
    });
    // TODO: Wire to Convex query in Task 8
  };

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
  };
}
