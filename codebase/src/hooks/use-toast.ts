import { useState } from 'react';
import { Toaster, toast as sonnerToast } from 'sonner';

type ToastProps = {
  title: string | React.ReactNode;
  description?: string | React.ReactNode;
  action?: React.ReactNode;
};

const useSonnerToast = () => {
  const [activeToasts, setActiveToasts] = useState<{
    id: string;
    props: ToastProps;
    dismiss: () => void;
  }[]>([]);

  const toast = (props: ToastProps) => {
    const { id, dismiss } = sonnerToast(
      props.title,
      {
        description: props.description,
        action: props.action,
        duration: 10000, // Assuming 10 seconds as per likely typo in original
      },
    );
    setActiveToasts((prev) => [...prev, { id, props, dismiss }]);
    return {
      id,
      dismiss,
      update: (newProps: Partial<ToastProps>) => {
        // Dismiss old toast and create new with updated props
        dismiss();
        const mergedProps = { ...props, ...newProps };
        const { id: newId, dismiss: newDismiss } = sonnerToast(
          mergedProps.title,
          {
            description: mergedProps.description,
            action: mergedProps.action,
            duration: 10000,
          },
        );
        setActiveToasts((prev) => {
          return prev
            .map((t) => {
              if (t.id === id) {
                return { id: newId, props: mergedProps, dismiss: newDismiss };
              }
              return t;
            })
            .filter((t) => t.id !== id);
        });
        return { id: newId, dismiss: newDismiss };
      },
    };
  };

  const dismiss = (id?: string) => {
    if (id) {
      const toast = activeToasts.find((t) => t.id === id);
      if (toast) {
        toast.dismiss();
        setActiveToasts((prev) => prev.filter((t) => t.id !== id));
      }
    } else {
      activeToasts.forEach((t) => t.dismiss());
      setActiveToasts([]);
    }
  };

  return { toast, dismiss };
};