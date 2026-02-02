import { useState, useCallback, useEffect, useRef } from "react";
import { useMutation } from "convex/react";
import { api } from "../../convex/_generated/api";

/**
 * Coordinates with source information
 */
export interface LocationData {
  lat: number;
  lng: number;
  source: 'gps' | 'manual';
}

/**
 * Return type for useUserLocation hook
 */
export interface UseUserLocationReturn {
  location: LocationData | null;
  isLoading: boolean;
  error: string | null;
  requestLocation: () => Promise<void>;
  setManualCity: (city: string) => Promise<void>;
}

/**
 * Haversine formula to calculate distance between two coordinates in meters
 */
function calculateDistance(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number
): number {
  const R = 6371000; // Earth's radius in meters
  const φ1 = (lat1 * Math.PI) / 180;
  const φ2 = (lat2 * Math.PI) / 180;
  const Δφ = ((lat2 - lat1) * Math.PI) / 180;
  const Δλ = ((lng2 - lng1) * Math.PI) / 180;

  const a =
    Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
    Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c; // Distance in meters
}

/**
 * Geocode a city name to coordinates using Nominatim (OpenStreetMap)
 */
async function geocodeCity(city: string): Promise<{ lat: number; lng: number } | null> {
  try {
    const response = await fetch(
      `https://nominatim.openstreetmap.org/search?format=json&q=${encodeURIComponent(city)}&limit=1`,
      {
        headers: {
          'User-Agent': 'Patchwork-App/1.0',
        },
      }
    );

    if (!response.ok) {
      throw new Error('Geocoding failed');
    }

    const data = await response.json();
    if (data.length === 0) {
      return null;
    }

    return {
      lat: parseFloat(data[0].lat),
      lng: parseFloat(data[0].lon),
    };
  } catch (error) {
    console.error('Geocoding error:', error);
    return null;
  }
}

/**
 * Hook for managing user location with GPS and city fallback
 * 
 * Features:
 * - Browser geolocation API integration
 * - 15-minute polling interval
 * - Smart push: only updates server if moved >500m
 * - City fallback when GPS is denied
 * - Comprehensive error handling
 */
export function useUserLocation(): UseUserLocationReturn {
  const [location, setLocation] = useState<LocationData | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  
  // Track last server update to implement 500m threshold
  const lastServerUpdate = useRef<{ lat: number; lng: number } | null>(null);
  const pollingInterval = useRef<number | null>(null);

  const updateLocationMutation = useMutation(api.users.updateLocation);

  /**
   * Update server location if user has moved >500m
   */
  const updateServerLocation = useCallback(async (
    lat: number,
    lng: number,
    source: 'gps' | 'manual'
  ) => {
    try {
      // Check if we need to update server (500m threshold)
      if (lastServerUpdate.current) {
        const distance = calculateDistance(
          lastServerUpdate.current.lat,
          lastServerUpdate.current.lng,
          lat,
          lng
        );

        // Skip update if moved less than 500m
        if (distance < 500) {
          return;
        }
      }

      // Update server
      await updateLocationMutation({
        lat,
        lng,
        source,
      });

      // Track last server update
      lastServerUpdate.current = { lat, lng };
    } catch (err) {
      console.error('Failed to update server location:', err);
      // Don't throw - this is a background update
    }
  }, [updateLocationMutation]);

  /**
   * Get current position from browser geolocation API
   */
  const getCurrentPosition = useCallback((): Promise<GeolocationPosition> => {
    return new Promise((resolve, reject) => {
      if (!navigator.geolocation) {
        reject(new Error('Geolocation is not supported by your browser'));
        return;
      }

      navigator.geolocation.getCurrentPosition(
        (position) => resolve(position),
        (error) => reject(error),
        {
          enableHighAccuracy: true,
          timeout: 10000,
          maximumAge: 0,
        }
      );
    });
  }, []);

  /**
   * Request location from GPS
   */
  const requestLocation = useCallback(async () => {
    setIsLoading(true);
    setError(null);

    try {
      const position = await getCurrentPosition();
      const newLocation: LocationData = {
        lat: position.coords.latitude,
        lng: position.coords.longitude,
        source: 'gps',
      };

      setLocation(newLocation);
      await updateServerLocation(newLocation.lat, newLocation.lng, 'gps');
    } catch (err) {
      let errorMessage = 'Failed to get your location';

      if (err instanceof GeolocationPositionError) {
        switch (err.code) {
          case err.PERMISSION_DENIED:
            errorMessage = 'Location permission denied. Please enter your city manually.';
            break;
          case err.POSITION_UNAVAILABLE:
            errorMessage = 'Location information unavailable. Please try again or enter your city.';
            break;
          case err.TIMEOUT:
            errorMessage = 'Location request timed out. Please try again.';
            break;
        }
      } else if (err instanceof Error) {
        errorMessage = err.message;
      }

      setError(errorMessage);
      console.error('Location error:', err);
    } finally {
      setIsLoading(false);
    }
  }, [getCurrentPosition, updateServerLocation]);

  /**
   * Set location from city name (fallback when GPS denied)
   */
  const setManualCity = useCallback(async (city: string) => {
    setIsLoading(true);
    setError(null);

    try {
      const coords = await geocodeCity(city);
      
      if (!coords) {
        throw new Error('Could not find coordinates for this city. Please try a different city name.');
      }

      const newLocation: LocationData = {
        lat: coords.lat,
        lng: coords.lng,
        source: 'manual',
      };

      setLocation(newLocation);
      await updateServerLocation(newLocation.lat, newLocation.lng, 'manual');
    } catch (err) {
      const errorMessage = err instanceof Error 
        ? err.message 
        : 'Failed to geocode city. Please try again.';
      
      setError(errorMessage);
      console.error('Geocoding error:', err);
    } finally {
      setIsLoading(false);
    }
  }, [updateServerLocation]);

  /**
   * Setup 15-minute polling for GPS location
   */
  useEffect(() => {
    // Only poll if we have GPS location
    if (!location || location.source !== 'gps') {
      return;
    }

    // Clear existing interval
    if (pollingInterval.current !== null) {
      window.clearInterval(pollingInterval.current);
    }

    // Poll every 15 minutes (900000 ms)
    pollingInterval.current = window.setInterval(() => {
      // Silent update - don't show loading state
      getCurrentPosition()
        .then((position) => {
          const newLocation: LocationData = {
            lat: position.coords.latitude,
            lng: position.coords.longitude,
            source: 'gps',
          };

          setLocation(newLocation);
          updateServerLocation(newLocation.lat, newLocation.lng, 'gps');
        })
        .catch((err) => {
          console.error('Background location update failed:', err);
          // Don't update error state for background failures
        });
    }, 15 * 60 * 1000); // 15 minutes

    // Cleanup on unmount or location change
    return () => {
      if (pollingInterval.current !== null) {
        window.clearInterval(pollingInterval.current);
        pollingInterval.current = null;
      }
    };
  }, [location, getCurrentPosition, updateServerLocation]);

  return {
    location,
    isLoading,
    error,
    requestLocation,
    setManualCity,
  };
}
