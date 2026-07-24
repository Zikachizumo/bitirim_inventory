import React from 'react';

/**
 * Bitirim — onaylanmis mockup'taki cizgi ikon seti.
 * Hepsi currentColor kullanir; renk CSS'ten (seviye temasi) gelir.
 */

type P = { className?: string; size?: number | string };

const svg =
  (children: React.ReactNode, opts?: { fill?: boolean; width?: number }) =>
  ({ className, size = 24 }: P) => (
    <svg
      className={className}
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill={opts?.fill ? 'currentColor' : 'none'}
      stroke={opts?.fill ? 'none' : 'currentColor'}
      strokeWidth={opts?.width ?? 1.6}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      {children}
    </svg>
  );

/* --- marka / ust bar --- */
export const IconBrandBag = svg(
  <>
    <path d="M4.5 11a5.5 5.5 0 015.5-5.5h4A5.5 5.5 0 0119.5 11v8a2 2 0 01-2 2h-11a2 2 0 01-2-2z" />
    <path d="M9.2 6.2V5a2.8 2.8 0 015.6 0v1.2" />
    <rect x="9" y="13" width="6" height="5.4" rx="1.3" />
    <path d="M9 15.6h6M4.6 12.4h2.3M17.1 12.4h2.3" />
  </>,
  { width: 1.55 }
);

export const IconClose = svg(<path d="M6 6l12 12M18 6L6 18" />, { width: 1.8 });

export const IconCash = svg(
  <>
    <rect x="2.5" y="6" width="19" height="12" rx="2.5" />
    <circle cx="12" cy="12" r="2.6" />
    <path d="M6 9.5v5M18 9.5v5" />
  </>
);

/* --- ekipman slotlari --- */
export const IconCap = svg(
  <>
    <path d="M4 15a8 8 0 0116 0" />
    <path d="M12 7v8" />
    <path d="M20 15c1.6 0 2.5.6 2.5 1.5S21.6 18 20 18H4" />
  </>
);

export const IconGlasses = svg(
  <>
    <circle cx="6.5" cy="13" r="3.2" />
    <circle cx="17.5" cy="13" r="3.2" />
    <path d="M9.7 12.5c1-1 3.6-1 4.6 0M3.3 12L5 8.5M20.7 12L19 8.5" />
  </>
);

export const IconHeadphones = svg(
  <>
    <path d="M4 14v-2a8 8 0 0116 0v2" />
    <rect x="3" y="13" width="4" height="6" rx="1.6" />
    <rect x="17" y="13" width="4" height="6" rx="1.6" />
  </>
);

export const IconMask = svg(
  <>
    <path d="M4 8c3-1 13-1 16 0 0 6-2 10-8 10S4 14 4 8z" />
    <path d="M9 12h.01M15 12h.01M9.5 15.5c1.5 1 3.5 1 5 0" />
  </>
);

export const IconRing = svg(
  <>
    <circle cx="12" cy="14" r="6" />
    <path d="M9.5 8l1.2-3.5h2.6L14.5 8" />
  </>
);

export const IconNecklace = svg(
  <>
    <path d="M5 5c1.5 6 12.5 6 14 0" />
    <path d="M12 11v3" />
    <path d="M12 18.5a2.4 2.4 0 100-4.8 2.4 2.4 0 000 4.8z" />
  </>
);

export const IconWatch = svg(
  <>
    <circle cx="12" cy="12" r="4.3" />
    <path d="M12 10.2V12l1.3.9" />
    <path d="M9.3 8L8.7 4.5h6.6L14.7 8M9.3 16l-.6 3.5h6.6L14.7 16" />
  </>
);

export const IconJacket = svg(
  <>
    <path d="M9 4l3 2 3-2 4 2.5-1.6 3.2L19 20H5l.6-8.3L4 6.5 8 4z" />
    <path d="M12 6v14" />
  </>
);

export const IconTshirt = svg(<path d="M8.5 4L4 7l2 3 2-1v9h8v-9l2 1 2-3-4.5-3a3 3 0 01-6 0z" />);

export const IconGloves = svg(
  <path d="M7 11V6.5a1.4 1.4 0 012.8 0V10m0-.5V5.2a1.4 1.4 0 012.8 0V10m0-1V6a1.4 1.4 0 012.8 0v5.5c0 4-2 7-5.3 7S7 16 6 14l-1.6-2.4a1.4 1.4 0 012.2-1.7z" />
);

export const IconVest = svg(
  <>
    <path d="M8 4l4 2 4-2 3 3v13H5V7z" />
    <path d="M12 6v14M8 10h1.5M14.5 10H16" />
  </>
);

export const IconBackpack = svg(
  <>
    <path d="M6 9a6 6 0 0112 0v10a1 1 0 01-1 1H7a1 1 0 01-1-1z" />
    <path d="M9 8a3 3 0 016 0" />
    <rect x="9" y="12" width="6" height="4.5" rx="1" />
  </>
);

export const IconPants = svg(
  <>
    <path d="M7 4h10l-.5 16H13l-1-9-1 9H7.5z" />
    <path d="M7 8h10" />
  </>
);

export const IconShoes = svg(
  <>
    <path d="M3 8v6c0 1 .6 1.6 1.6 1.7l14 1.3c1.3.1 2.4-.8 2.4-2 0-1-.6-1.6-1.8-2.1L14 12 10 7H4a1 1 0 00-1 1z" />
    <path d="M3 12h5" />
  </>
);

export const IconPistol = svg(
  <>
    <path d="M3 8h15v4h-4l-2 3H9l.5-3H6l-3 3z" />
    <path d="M6 12v3" />
  </>
);

export const IconAmmo = svg(
  <>
    <rect x="8" y="9" width="8" height="11" rx="1.4" />
    <path d="M9 9l1-4h4l1 4M8 13h8" />
  </>
);

/* --- statlar --- */
export const IconHeart = svg(
  <path d="M12 20s-7-4.3-9.2-8.5C1.2 8.3 2.6 5 5.8 5 8 5 9.3 6.5 12 9c2.7-2.5 4-4 6.2-4 3.2 0 4.6 3.3 3 6.5C19 15.7 12 20 12 20z" />,
  { fill: true }
);

export const IconShield = svg(<path d="M12 3l7 3v5c0 5-3 8-7 10-4-2-7-5-7-10V6z" />, { width: 1.7 });

export const IconFood = svg(<path d="M6 3v7a2 2 0 004 0V3M8 3v18M17 3c-1.5 0-2.5 2-2.5 5s1 4 2.5 4v9" />, {
  width: 1.7,
});

export const IconDrop = svg(<path d="M12 3s6 6.5 6 11a6 6 0 01-12 0c0-4.5 6-11 6-11z" />, { width: 1.7 });

/* --- diger --- */
export const IconWeight = svg(
  <>
    <path d="M9 7a3 3 0 116 0" />
    <path d="M6.5 7h11l2 12a1 1 0 01-1 1.2H5.5A1 1 0 014.5 19z" />
  </>
);

export const IconSend = svg(<path d="M21 3L10.5 13.5M21 3l-6.5 18-4-8-8-4z" />);

export const IconUser = svg(
  <>
    <circle cx="12" cy="8" r="3.6" />
    <path d="M5 20c0-3.5 3.1-5.5 7-5.5s7 2 7 5.5" />
  </>
);

export const IconInfo = svg(
  <>
    <circle cx="12" cy="12" r="9" />
    <path d="M12 11v5M12 8h.01" />
  </>,
  { width: 1.7 }
);

export const IconLock = svg(
  <>
    <rect x="5" y="10.5" width="14" height="9.5" rx="2" />
    <path d="M8 10.5V8a4 4 0 018 0v2.5" />
  </>
);
