import { useState, useEffect } from "react";
import { useQuery, useMutation, useConvexAuth } from "convex/react";
import { api } from "../convex/_generated/api";
import { useAuth } from "./lib/auth";
import { TaskerSuccess } from "./screens/TaskerSuccess";
import { Subscriptions } from "./screens/Subscriptions";
import { Splash } from "./screens/Splash";
import { Onboarding } from "./screens/Onboarding";
import { SignIn } from "./screens/SignIn";
import { CreateAccount } from "./screens/CreateAccount";
import { CreateProfile } from "./screens/CreateProfile";
import { LocationPermission } from "./screens/LocationPermission";
import { NotificationPermission } from "./screens/NotificationPermission";
import { ResetPassword } from "./screens/ResetPassword";
import { EmailEntry } from "./screens/EmailEntry";
import { EmailVerify } from "./screens/EmailVerify";
import { HomeSwipe } from "./screens/HomeSwipe";
import { Categories } from "./screens/Categories";
import { Browse } from "./screens/Browse";
import { ProviderDetail } from "./screens/ProviderDetail";
import { RequestStep1 } from "./screens/RequestStep1";
import { RequestStep2 } from "./screens/RequestStep2";
import { RequestStep3 } from "./screens/RequestStep3";
import { RequestStep4 } from "./screens/RequestStep4";
import { RequestSuccess } from "./screens/RequestSuccess";
import { Messages } from "./screens/Messages";
import { Chat } from "./screens/Chat";
import { Profile } from "./screens/Profile";
import { TaskerOnboarding1 } from "./screens/TaskerOnboarding1";
import { TaskerOnboarding2 } from "./screens/TaskerOnboarding2";
import { TaskerOnboarding4 } from "./screens/TaskerOnboarding4";
import { JobDetail } from "./screens/JobDetail";
import { LeaveReview } from "./screens/LeaveReview";
import { Help } from "./screens/Help";
import { Jobs } from "./screens/Jobs";
import { CategorySelection } from "./screens/CategorySelection";
import { AddCategory } from "./screens/AddCategory";
import { PremiumUpgrade } from "./screens/PremiumUpgrade";

type Screen = 
  | "splash"
  | "onboarding"
  | "location-permission"
  | "notification-permission"
  | "sign-in"
  | "create-account"
  | "create-profile"
  | "reset-password"
  | "home"
  | "categories"
  | "browse"
  | "provider-detail"
  | "request-step1"
  | "request-step2"
  | "request-step3"
  | "request-step4"
  | "request-success"
  | "messages"
  | "chat"
  | "profile"
  | "tasker-onboarding1"
  | "tasker-onboarding2"
  | "tasker-onboarding4"
  | "tasker-success"
  | "subscriptions"
  | "job-detail"
  | "leave-review"
  | "help"
  | "jobs"
  | "post-job"
  | "category-selection"
  | "profile-edit"
  | "addresses"
  | "add-category"
  | "email-entry"
  | "email-verify"
  | "premium-upgrade";

import { Id } from "../convex/_generated/dataModel";

export default function App() {
  const [currentScreen, setCurrentScreen] = useState<Screen>("home");
  const [history, setHistory] = useState<Screen[]>(["home"]);
  const [isTasker, setIsTasker] = useState(false);
  const [activeConversationId, setActiveConversationId] = useState<Id<"conversations"> | null>(null);
  const [activeJobId, setActiveJobId] = useState<Id<"jobs"> | null>(null);
  const [activeTaskerId, setActiveTaskerId] = useState<Id<"taskerProfiles"> | null>(null);
  // Mock user photo - in real app, would come from CreateProfile
  const [userPhoto] = useState<string>("");
  const [displayName, setDisplayName] = useState("");
  const [selectedCategories, setSelectedCategories] = useState<string[]>([]);
  const [categoryBio, setCategoryBio] = useState("");
  const [categoryRateType, setCategoryRateType] = useState<"hourly" | "fixed">("hourly");
  const [categoryHourlyRate, setCategoryHourlyRate] = useState("");
  const [categoryFixedRate, setCategoryFixedRate] = useState("");
  const [categoryServiceRadius, setCategoryServiceRadius] = useState(50);
  const [categoryPhotos, setCategoryPhotos] = useState<string[]>([]);
  const [pendingNewCategory, setPendingNewCategory] = useState<string | null>(null);
   const [verificationEmail, setVerificationEmail] = useState("");
   
   // Subscription tracking
   const [subscriptionPlan, setSubscriptionPlan] = useState<"none" | "basic" | "premium">("none"); // Mock: no subscription
   const [pendingCategories, setPendingCategories] = useState<string[]>([]);

   // Request form state (shared across RequestStep1-4)
   const [requestFormData, setRequestFormData] = useState({
     categoryId: "",
     categoryName: "",
     description: "",
     address: "",
     city: "",
     province: "",
     searchRadius: 25,
     timingType: "flexible" as "asap" | "specific_date" | "flexible",
     specificDate: "",
     specificTime: "",
     budgetMin: "",
     budgetMax: "",
   });

   // Auth state
   const { isAuthenticated, isLoading: authLoading } = useAuth();
   const { isAuthenticated: convexAuth, isLoading: convexAuthLoading } = useConvexAuth();
   const convexUser = useQuery(
     api.users.getCurrentUser,
     convexAuth ? {} : "skip"
   );
   const taskerProfile = useQuery(
     api.taskers.getTaskerProfile,
     convexAuth ? {} : "skip"
   );
  const categories = useQuery(api.categories.listCategories);
  const createTaskerProfile = useMutation(api.taskers.createTaskerProfile);
  const startConversation = useMutation(api.conversations.startConversation);

  const navigate = (screen: Screen | string) => {
    const validScreen = screen as Screen;
    setCurrentScreen(validScreen);
    setHistory(prev => [...prev, validScreen]);
  };

  const goBack = () => {
    if (history.length > 1) {
      const newHistory = history.slice(0, -1);
      setHistory(newHistory);
      setCurrentScreen(newHistory[newHistory.length - 1]);
    }
  };

  const handleTaskerOnboardingComplete = async () => {
    try {
      const categoryName = selectedCategories[0];
      const category = categories?.find(c => c.name === categoryName);
      
      if (!category) {
        console.error("Category not found:", categoryName);
        return;
      }

      const hourlyRateCents = categoryHourlyRate 
        ? Math.round(parseFloat(categoryHourlyRate) * 100) 
        : undefined;
      const fixedRateCents = categoryFixedRate 
        ? Math.round(parseFloat(categoryFixedRate) * 100) 
        : undefined;

      await createTaskerProfile({
        displayName,
        categoryId: category._id,
        categoryBio,
        photos: categoryPhotos.length > 0 ? categoryPhotos as any : undefined,
        rateType: categoryRateType,
        hourlyRate: hourlyRateCents,
        fixedRate: fixedRateCents,
        serviceRadius: categoryServiceRadius,
      });

      navigate("tasker-success");
    } catch (error) {
      console.error("Failed to create tasker profile:", error);
    }
  };

   // Sync subscription plan from tasker profile
   useEffect(() => {
     if (taskerProfile && taskerProfile.subscriptionPlan) {
       setSubscriptionPlan(taskerProfile.subscriptionPlan);
     }
   }, [taskerProfile?.subscriptionPlan]);

   // Smart redirect based on auth state
   useEffect(() => {
     if (authLoading || convexAuthLoading) return;

     const authScreens = ["sign-in", "create-account", "email-entry", "email-verify", "onboarding", "splash"];
     const protectedScreens = ["home", "profile", "messages", "jobs", "browse", "categories"];

     if (!isAuthenticated || !convexAuth) {
       if (protectedScreens.includes(currentScreen) || currentScreen === "home") {
         navigate("splash");
       }
       return;
     }

     if (convexUser === undefined) return;

     if (convexUser === null) {
       if (currentScreen !== "create-profile") {
         navigate("create-profile");
       }
       return;
     }

     if (authScreens.includes(currentScreen)) {
       navigate("home");
     }
   }, [
     authLoading,
     convexAuthLoading,
     isAuthenticated,
     convexAuth,
     convexUser,
     currentScreen,
   ]);

  const renderScreen = () => {
    switch (currentScreen) {
      case "splash":
        return <Splash onGetStarted={() => navigate("onboarding")} />;
      
      case "onboarding":
        return <Onboarding onComplete={() => navigate("sign-in")} />;
      
      case "sign-in":
        return (
          <SignIn
            onCreateAccount={() => navigate("create-account")}
            onEmailSignIn={() => navigate("email-entry")}
          />
        );
      
      case "create-account":
        return (
          <CreateAccount
            onBack={goBack}
          />
        );
      
      case "create-profile":
        return (
          <CreateProfile
            onContinue={() => navigate("location-permission")}
          />
        );
      
      case "location-permission":
        return (
          <LocationPermission
            onAllow={() => navigate("notification-permission")}
            onSkip={() => navigate("notification-permission")}
          />
        );
      
      case "notification-permission":
        return (
          <NotificationPermission
            onAllow={() => navigate("home")}
            onSkip={() => navigate("home")}
          />
        );
      
      case "reset-password":
        return (
          <ResetPassword
            onBack={goBack}
            onSent={() => navigate("sign-in")}
          />
        );
      
      case "home":
        return (
          <HomeSwipe 
            onNavigate={navigate} 
            onViewTasker={(id) => {
              setActiveTaskerId(id);
              navigate("provider-detail");
            }}
          />
        );
      
      case "categories":
        return <Categories onNavigate={navigate} onBack={goBack} />;
      
      case "browse":
        return (
          <Browse 
            onNavigate={navigate} 
            onBack={goBack}
            onViewTasker={(id) => {
              setActiveTaskerId(id);
              navigate("provider-detail");
            }}
          />
        );
      
      case "provider-detail":
        return (
          <ProviderDetail
            taskerId={activeTaskerId}
            onBack={goBack}
            onNavigate={navigate}
            onStartChat={async (taskerUserId) => {
              const conversationId = await startConversation({ taskerId: taskerUserId });
              setActiveConversationId(conversationId);
              navigate("chat");
            }}
          />
        );
      
       case "request-step1":
       case "post-job":
         return (
           <RequestStep1
             onBack={goBack}
             onNext={() => navigate("request-step2")}
             formData={requestFormData}
             onFormChange={setRequestFormData}
           />
         );
       
       case "request-step2":
         return (
           <RequestStep2
             onBack={goBack}
             onNext={() => navigate("request-step3")}
             formData={requestFormData}
             onFormChange={setRequestFormData}
           />
         );
       
       case "request-step3":
         return (
           <RequestStep3
             onBack={goBack}
             onNext={() => navigate("request-step4")}
             formData={requestFormData}
             onFormChange={setRequestFormData}
           />
         );
       
       case "request-step4":
         return (
           <RequestStep4
             onBack={goBack}
             onSubmit={() => navigate("request-success")}
             formData={requestFormData}
             onFormChange={setRequestFormData}
           />
         );
      
      case "request-success":
        return (
          <RequestSuccess
            onViewRequests={() => navigate("home")}
            onHome={() => navigate("home")}
          />
        );
      
      case "messages":
        return (
          <Messages
            onNavigate={navigate}
            onOpenChat={(id) => {
              setActiveConversationId(id);
              navigate("chat");
            }}
            isTasker={isTasker}
          />
        );
      
      case "chat":
        return <Chat onBack={goBack} conversationId={activeConversationId || undefined} />;
      
      case "profile":
        return (
          <Profile
            onNavigate={navigate}
            onSwitchToTasker={() => navigate("tasker-onboarding1")}
            isTasker={isTasker}
            userPhoto={userPhoto}
            taskerCategories={selectedCategories}
            taskerCategoryBio={categoryBio}
            taskerCategoryRateType={categoryRateType}
            taskerCategoryHourlyRate={categoryHourlyRate}
            taskerCategoryFixedRate={categoryFixedRate}
            taskerCategoryServiceRadius={categoryServiceRadius}
            taskerCategoryPhotos={categoryPhotos}
            pendingNewCategory={pendingNewCategory}
            onCategoryModalClosed={() => setPendingNewCategory(null)}
            onCategoryRemoved={(category) => {
              setSelectedCategories(selectedCategories.filter(c => c !== category));
            }}
            subscriptionPlan={subscriptionPlan}
          />
        );
      
       case "tasker-onboarding1":
         return (
           <TaskerOnboarding1
             onBack={goBack}
             onNext={() => navigate("tasker-onboarding2")}
             onSeeAllCategories={() => navigate("category-selection")}
             userPhoto={userPhoto}
             displayName={displayName}
             onDisplayNameChange={setDisplayName}
             selectedCategories={selectedCategories}
             onCategoriesChange={setSelectedCategories}
           />
         );
      
      case "tasker-onboarding2":
        return (
          <TaskerOnboarding2
            onBack={goBack}
            onNext={(data) => {
              setCategoryBio(data.bio);
              setCategoryRateType(data.rateType);
              setCategoryHourlyRate(data.hourlyRate);
              setCategoryFixedRate(data.fixedRate);
              setCategoryServiceRadius(data.serviceRadius);
              setCategoryPhotos(data.photos);
              navigate("tasker-onboarding4");
            }}
          />
        );
      
      case "tasker-onboarding4":
        return (
          <TaskerOnboarding4
            onBack={goBack}
            onComplete={handleTaskerOnboardingComplete}
          />
        );
      
      case "tasker-success":
        return (
          <TaskerSuccess
            onSubscribe={() => navigate("subscriptions")}
          />
        );
      
      case "subscriptions":
        return (
          <Subscriptions
            onBack={goBack}
            onSubscribe={(plan) => {
              // Update subscription plan
              setSubscriptionPlan(plan);
              setIsTasker(true);
              
              // Apply pending categories if any
              if (pendingCategories.length > 0) {
                setSelectedCategories(pendingCategories);
                setPendingCategories([]);
              }
              
              // Exit ghost mode when activating subscription
              navigate("profile");
            }}
            onSkip={() => {
              setIsTasker(true);
              navigate("profile");
            }}
          />
        );
      
      case "job-detail":
        if (!activeJobId) return <HomeSwipe onNavigate={navigate} />;
        return <JobDetail jobId={activeJobId} onBack={goBack} onNavigate={navigate} />;
      
      case "leave-review":
        return (
          <LeaveReview
            onBack={goBack}
            onSubmit={() => navigate("home")}
          />
        );
      
      case "help":
        return <Help onBack={goBack} />;
      
      case "jobs":
        return (
          <Jobs
            onNavigate={navigate}
            onOpenJob={(id) => {
              setActiveJobId(id);
              navigate("job-detail");
            }}
          />
        );
      
      case "category-selection":
        return (
          <CategorySelection
            onBack={goBack}
            onConfirm={(categories) => {
              // Check if user needs Premium subscription for multiple categories
              if (categories.length > 1 && (subscriptionPlan === "none" || subscriptionPlan === "basic")) {
                // Save pending categories and show upgrade modal
                setPendingCategories(categories);
                navigate("premium-upgrade");
              } else {
                // Premium or only 1 category - allow it
                setSelectedCategories(categories);
                goBack();
              }
            }}
            preSelected={selectedCategories}
          />
        );
      
      case "profile-edit":
      case "addresses":
        return (
          <div className="min-h-screen bg-neutral-50 flex items-center justify-center px-4">
            <div className="text-center">
              <h1 className="text-neutral-900 mb-4">Coming Soon</h1>
              <p className="text-neutral-600 mb-6">This screen is under development</p>
              <button
                onClick={goBack}
                className="px-6 py-3 bg-[#4F46E5] text-white rounded-lg"
              >
                Go Back
              </button>
            </div>
          </div>
        );
      
      case "add-category":
        return (
          <AddCategory
            onBack={goBack}
            onAdd={(category) => {
              setSelectedCategories([...selectedCategories, category]);
              setPendingNewCategory(category);
              goBack();
            }}
            existingCategories={selectedCategories}
          />
        );
      
      case "email-entry":
        return (
          <EmailEntry
            onBack={goBack}
            onSendCode={(email) => {
              setVerificationEmail(email);
              // In a real app, this would send the code via API
              console.log("Sending verification code to:", email);
              navigate("email-verify");
            }}
          />
        );
      
      case "email-verify":
        return (
          <EmailVerify
            email={verificationEmail}
            onBack={goBack}
            onVerify={(code) => {
              console.log("Verifying code:", code);
              navigate("home");
            }}
            onResendCode={() => {
              // In a real app, this would resend the code via API
              console.log("Resending verification code to:", verificationEmail);
            }}
            onBackToSignIn={() => {
              navigate("sign-in");
            }}
          />
        );
      
      case "premium-upgrade":
        return (
          <PremiumUpgrade
            onBack={goBack}
            onUpgrade={() => {
              // Navigate to subscriptions page to complete premium upgrade
              navigate("subscriptions");
            }}
          />
        );
      
      default:
        return <HomeSwipe onNavigate={navigate} />;
    }
  };

  return (
    <div className="max-w-[390px] mx-auto bg-white min-h-screen relative">
      {renderScreen()}
    </div>
  );
}
