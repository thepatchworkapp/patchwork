import { useState } from "react";
import { Camera } from "lucide-react";
import { useMutation } from "convex/react";
import { api } from "../../convex/_generated/api";
import { Button } from "../components/patchwork/Button";
import { Input } from "../components/patchwork/Input";

export function CreateProfile({ onContinue }: { onContinue: () => void }) {
  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [city, setCity] = useState("");
  const [province, setProvince] = useState("");
  const [profileImage, setProfileImage] = useState<string | null>(null);
  const [photoStorageId, setPhotoStorageId] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState("");

  const generateUploadUrl = useMutation(api.files.generateUploadUrl);
  const createProfile = useMutation(api.users.createProfile);

  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onloadend = () => {
      setProfileImage(reader.result as string);
    };
    reader.readAsDataURL(file);

    try {
      setError("");
      
      const uploadUrl = await generateUploadUrl({
        contentType: file.type,
        fileSize: file.size,
      });
      const result = await fetch(uploadUrl, {
        method: "POST",
        headers: { "Content-Type": file.type },
        body: file,
      });
      
      if (!result.ok) {
        throw new Error(`Upload failed: ${result.statusText}`);
      }
      
      const { storageId } = await result.json();
      setPhotoStorageId(storageId);
    } catch (err) {
      console.error("Upload failed:", err);
      setError("Failed to upload photo. Please try again.");
    }
  };

  const handleSubmit = async () => {
    if (!firstName || !lastName || !city || !province) {
      setError("Please fill in all fields");
      return;
    }

    setIsLoading(true);
    setError("");

    try {
      await createProfile({
        name: `${firstName} ${lastName}`,
        city,
        province,
        photo: photoStorageId || undefined,
      });
      onContinue();
    } catch (err) {
      console.error("Create profile failed:", err);
      setError("Failed to create profile. Please try again.");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-white flex flex-col">
      <div className="flex-1 px-4 pt-12 flex flex-col">
        <div className="mb-8 text-center">
          <h1 className="text-neutral-900 mb-2">Create your profile</h1>
          <p className="text-[#6B7280]">
            Let's get started with some basic information
          </p>
        </div>

        {/* Profile Picture Upload */}
        <div className="mb-8 flex justify-center">
          <label className="relative cursor-pointer">
            <input
              type="file"
              accept="image/*"
              onChange={handleImageUpload}
              className="hidden"
            />
            <div className="relative">
              {profileImage ? (
                <img
                  src={profileImage}
                  alt="Profile"
                  className="size-32 rounded-full object-cover"
                />
              ) : (
                <div className="size-32 rounded-full bg-neutral-200 flex items-center justify-center">
                  <svg
                    width="64"
                    height="64"
                    viewBox="0 0 24 24"
                    fill="none"
                    xmlns="http://www.w3.org/2000/svg"
                    className="text-neutral-400"
                  >
                    <path
                      d="M12 12C14.21 12 16 10.21 16 8C16 5.79 14.21 4 12 4C9.79 4 8 5.79 8 8C8 10.21 9.79 12 12 12ZM12 14C9.33 14 4 15.34 4 18V20H20V18C20 15.34 14.67 14 12 14Z"
                      fill="currentColor"
                    />
                  </svg>
                </div>
              )}
              <div className="absolute bottom-0 right-0 size-10 rounded-full bg-white border-2 border-white shadow-lg flex items-center justify-center">
                <Camera size={20} className="text-[#4F46E5]" />
              </div>
            </div>
          </label>
        </div>

        {/* Form Fields */}
        <div className="space-y-4 mb-8">
          <Input
            type="text"
            label="First Name"
            placeholder="Jenny"
            value={firstName}
            onChange={(e) => setFirstName(e.target.value)}
          />
          
          <Input
            type="text"
            label="Last Name"
            placeholder="Mabel"
            value={lastName}
            onChange={(e) => setLastName(e.target.value)}
          />

          <Input
            type="text"
            label="City"
            placeholder="Toronto"
            value={city}
            onChange={(e) => setCity(e.target.value)}
          />

          <Input
            type="text"
            label="Province"
            placeholder="ON"
            value={province}
            onChange={(e) => setProvince(e.target.value)}
          />
        </div>

        {error && (
            <div className="mb-4 text-center text-red-500 text-sm">
                {error}
            </div>
        )}

        {/* Continue Button */}
        <div className="mt-auto pb-8">
          <Button 
            variant="primary" 
            fullWidth 
            onClick={handleSubmit}
            disabled={isLoading || !firstName || !lastName || !city || !province}
          >
            {isLoading ? "Creating..." : "Continue"}
          </Button>
        </div>
      </div>
    </div>
  );
}
