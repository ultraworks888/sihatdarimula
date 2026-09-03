const LOGO_SRC = "/public_423c_17351677b8b244428bdb9895249c6fca.webp";

interface AppLogoProps {
  size?: number;
  className?: string;
}

export default function AppLogo({ size = 80, className = "" }: AppLogoProps) {
  return (
    <img
      src={LOGO_SRC}
      alt="My Healthy Start — Sihat Dari Mula"
      width={size}
      height={size}
      className={`object-contain select-none ${className}`}
      draggable={false}
    />
  );
}

export { LOGO_SRC };
