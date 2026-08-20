import { useAuth } from "@clerk/expo";
import { useConvexAuth, useMutation } from "convex/react";
import { useEffect } from "react";
import { api } from "@/convex/_generated/api";

export function StoreUser() {
  const { isSignedIn } = useAuth({ treatPendingAsSignedOut: false });
  const { isAuthenticated, isLoading } = useConvexAuth();
  const store = useMutation(api.users.store);

  useEffect(() => {
    if (!isSignedIn || isLoading || !isAuthenticated) return;
    void store({}).catch(() => {
      // Auth may still be settling; babies screen will retry via reactive queries.
    });
  }, [isSignedIn, isAuthenticated, isLoading, store]);

  return null;
}
