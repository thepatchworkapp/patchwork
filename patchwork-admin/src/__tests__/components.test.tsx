import { expect, test, describe, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import { Login } from "../pages/Login";

describe("Login component", () => {
  test("renders login page", () => {
    vi.mock("../context/AuthContext", () => ({
      useAuth: () => ({
        login: vi.fn(),
      }),
    }));

    render(<Login />);

    expect(screen.getByText("Admin Login")).toBeDefined();
    expect(screen.getByText("Patchwork Admin Dashboard")).toBeDefined();
  });

  test("renders email input field", () => {
    vi.mock("../context/AuthContext", () => ({
      useAuth: () => ({
        login: vi.fn(),
      }),
    }));

    render(<Login />);

    const emailInput = screen.queryByDisplayValue("daveald@gmail.com");
    expect(emailInput).toBeDefined();
  });

  test("renders OTP input field", () => {
    vi.mock("../context/AuthContext", () => ({
      useAuth: () => ({
        login: vi.fn(),
      }),
    }));

    render(<Login />);

    const otpInput = screen.queryByPlaceholderText(/OTP|otp|code/i);
    expect(otpInput).toBeDefined();
  });

  test("renders send OTP button", () => {
    vi.mock("../context/AuthContext", () => ({
      useAuth: () => ({
        login: vi.fn(),
      }),
    }));

    render(<Login />);

    const sendButton = screen.queryByText(/Send OTP|send/i);
    expect(sendButton).toBeDefined();
  });
});
