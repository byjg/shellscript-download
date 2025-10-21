interface InstructionStepProps {
  number: string;
  title: string;
  description: string;
}

export const InstructionStep = ({ number, title, description }: InstructionStepProps) => {
  return (
    <div className="flex gap-6">
      <div className="flex h-12 w-12 flex-shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-accent to-accent/70 text-2xl font-bold text-accent-foreground shadow-lg">
        {number}
      </div>
      <div className="flex-1">
        <h3 className="mb-2 text-lg font-semibold text-foreground">{title}</h3>
        <p className="text-muted-foreground">{description}</p>
      </div>
    </div>
  );
};
